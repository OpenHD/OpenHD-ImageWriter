/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include "diskformatter.h"
#include "file_operations.h"
#include "openhdprovisioning.h"

#include <QtEndian>
#include <QUuid>

#include <algorithm>
#include <array>
#include <cstring>
#include <limits>
#include <memory>
#include <vector>

namespace {

constexpr quint32 SectorSize = 512;
constexpr quint32 PartitionStart = 8192;
constexpr quint16 ReservedSectors = 32;
constexpr quint8 FatCount = 2;

#pragma pack(push, 1)
struct MbrPartitionEntry
{
    quint8 status;
    quint8 firstHead;
    quint8 firstSector;
    quint8 firstCylinder;
    quint8 partitionType;
    quint8 lastHead;
    quint8 lastSector;
    quint8 lastCylinder;
    quint32 firstLba;
    quint32 sectorCount;
};

struct Fat32BootSector
{
    quint8 jump[3];
    char oemName[8];
    quint16 bytesPerSector;
    quint8 sectorsPerCluster;
    quint16 reservedSectors;
    quint8 fatCount;
    quint16 rootEntries;
    quint16 totalSectors16;
    quint8 mediaDescriptor;
    quint16 sectorsPerFat16;
    quint16 sectorsPerTrack;
    quint16 headCount;
    quint32 hiddenSectors;
    quint32 totalSectors32;
    quint32 sectorsPerFat32;
    quint16 extendedFlags;
    quint16 filesystemVersion;
    quint32 rootCluster;
    quint16 fsInfoSector;
    quint16 backupBootSector;
    quint8 reserved[12];
    quint8 driveNumber;
    quint8 reserved1;
    quint8 bootSignature;
    quint32 volumeId;
    char volumeLabel[11];
    char filesystemType[8];
    quint8 bootCode[420];
    quint16 signature;
};

struct Fat32FsInfo
{
    quint32 leadSignature;
    quint8 reserved1[480];
    quint32 structureSignature;
    quint32 freeClusterCount;
    quint32 nextFreeCluster;
    quint8 reserved2[12];
    quint32 trailSignature;
};
#pragma pack(pop)

static_assert(sizeof(MbrPartitionEntry) == 16, "Invalid MBR entry size");
static_assert(sizeof(Fat32BootSector) == SectorSize, "Invalid FAT32 boot-sector size");
static_assert(sizeof(Fat32FsInfo) == SectorSize, "Invalid FAT32 FSInfo size");

struct FatLayout
{
    quint32 totalSectors = 0;
    quint32 sectorsPerFat = 0;
    quint32 clusterCount = 0;
    quint8 sectorsPerCluster = 0;
};

DiskFormatError writeAt(FileOperations &file, quint64 offset,
                        const quint8 *data, std::size_t size)
{
    if (file.seek(offset) != FileError::Success) return DiskFormatError::SeekFailed;
    std::size_t written = 0;
    if (file.writeSequential(data, size, written) != FileError::Success || written != size)
        return DiskFormatError::WriteFailed;
    return DiskFormatError::Success;
}

DiskFormatError writeZeroes(FileOperations &file, quint64 offset, quint64 size)
{
    std::vector<quint8> zeroes(1024 * 1024, 0);
    while (size)
    {
        const std::size_t chunk = static_cast<std::size_t>(
            std::min<quint64>(size, zeroes.size()));
        const DiskFormatError result = writeAt(file, offset, zeroes.data(), chunk);
        if (result != DiskFormatError::Success) return result;
        offset += chunk;
        size -= chunk;
    }
    return DiskFormatError::Success;
}

quint32 sectorsPerFat(quint32 totalSectors, quint8 sectorsPerCluster)
{
    quint32 current = 1;
    for (int iteration = 0; iteration < 16; ++iteration)
    {
        const quint64 overhead = ReservedSectors + static_cast<quint64>(FatCount) * current;
        if (overhead >= totalSectors) return 0;
        const quint32 clusters = static_cast<quint32>(
            (totalSectors - overhead) / sectorsPerCluster);
        const quint32 calculated = static_cast<quint32>(
            (static_cast<quint64>(clusters + 2) * sizeof(quint32) +
             SectorSize - 1) / SectorSize);
        if (calculated <= current) return current;
        current = calculated;
    }
    return current;
}

bool calculateLayout(quint64 deviceBytes, FatLayout &layout, quint32 firstSector = PartitionStart)
{
    const quint64 deviceSectors = deviceBytes / SectorSize;
    if (deviceSectors <= quint64(firstSector) + ReservedSectors)
        return false;
    const quint64 usable = std::min<quint64>(
        deviceSectors, std::numeric_limits<quint32>::max()) - firstSector;
    layout.totalSectors = static_cast<quint32>(usable);

    quint8 preferred = 1;
    if (layout.totalSectors >= 532480) preferred = 8;
    if (layout.totalSectors >= 16777216) preferred = 16;
    if (layout.totalSectors >= 33554432) preferred = 32;

    const quint8 candidates[] = {preferred, 1, 2, 4, 8, 16, 32, 64, 128};
    for (quint8 candidate : candidates)
    {
        const quint32 fatSectors = sectorsPerFat(layout.totalSectors, candidate);
        const quint64 overhead = ReservedSectors +
                                 static_cast<quint64>(FatCount) * fatSectors;
        if (!fatSectors || overhead >= layout.totalSectors) continue;
        const quint32 clusters = static_cast<quint32>(
            (layout.totalSectors - overhead) / candidate);
        if (clusters >= 65525 && clusters <= 0x0FFFFFF5)
        {
            layout.sectorsPerCluster = candidate;
            layout.sectorsPerFat = fatSectors;
            layout.clusterCount = clusters;
            return true;
        }
    }
    return false;
}

Fat32BootSector makeBootSector(const FatLayout &layout, const QByteArray &label)
{
    Fat32BootSector sector = {};
    sector.jump[0] = 0xEB;
    sector.jump[1] = 0x58;
    sector.jump[2] = 0x90;
    std::memcpy(sector.oemName, "OPENHD  ", 8);
    sector.bytesPerSector = qToLittleEndian<quint16>(SectorSize);
    sector.sectorsPerCluster = layout.sectorsPerCluster;
    sector.reservedSectors = qToLittleEndian<quint16>(ReservedSectors);
    sector.fatCount = FatCount;
    sector.mediaDescriptor = 0xF8;
    sector.sectorsPerTrack = qToLittleEndian<quint16>(63);
    sector.headCount = qToLittleEndian<quint16>(255);
    sector.hiddenSectors = qToLittleEndian<quint32>(PartitionStart);
    sector.totalSectors32 = qToLittleEndian<quint32>(layout.totalSectors);
    sector.sectorsPerFat32 = qToLittleEndian<quint32>(layout.sectorsPerFat);
    sector.rootCluster = qToLittleEndian<quint32>(2);
    sector.fsInfoSector = qToLittleEndian<quint16>(1);
    sector.backupBootSector = qToLittleEndian<quint16>(6);
    sector.driveNumber = 0x80;
    sector.bootSignature = 0x29;
    sector.volumeId = qToLittleEndian<quint32>(0x4F484400U ^ layout.totalSectors);
    std::memset(sector.volumeLabel, ' ', sizeof(sector.volumeLabel));
    const QByteArray normalized = label.trimmed().toUpper().left(11);
    std::memcpy(sector.volumeLabel, normalized.constData(),
                static_cast<std::size_t>(normalized.size()));
    std::memcpy(sector.filesystemType, "FAT32   ", 8);
    sector.signature = qToLittleEndian<quint16>(0xAA55);
    return sector;
}

Fat32FsInfo makeFsInfo(const FatLayout &layout)
{
    Fat32FsInfo info = {};
    info.leadSignature = qToLittleEndian<quint32>(0x41615252);
    info.structureSignature = qToLittleEndian<quint32>(0x61417272);
    info.freeClusterCount = qToLittleEndian<quint32>(layout.clusterCount - 1);
    info.nextFreeCluster = qToLittleEndian<quint32>(3);
    info.trailSignature = qToLittleEndian<quint32>(0xAA550000);
    return info;
}

std::array<quint8, SectorSize> makeMbr(const FatLayout &layout)
{
    std::array<quint8, SectorSize> mbr = {};
    MbrPartitionEntry partition = {};
    partition.firstHead = 0x20;
    partition.firstSector = 0x21;
    partition.partitionType = 0x0C;
    partition.lastHead = 0xFE;
    partition.lastSector = 0xFF;
    partition.lastCylinder = 0xFF;
    partition.firstLba = qToLittleEndian<quint32>(PartitionStart);
    partition.sectorCount = qToLittleEndian<quint32>(layout.totalSectors);
    const quint32 diskSignature = qToLittleEndian<quint32>(0x4F484400U ^ layout.totalSectors);
    std::memcpy(mbr.data() + 440, &diskSignature, sizeof(diskSignature));
    std::memcpy(mbr.data() + 446, &partition, sizeof(partition));
    mbr[510] = 0x55;
    mbr[511] = 0xAA;
    return mbr;
}

DiskFormatError formatPartition(FileOperations &file, quint64 partitionOffset,
                                const FatLayout &layout, const QByteArray &volumeLabel)
{
    Fat32BootSector bootSector = makeBootSector(layout, volumeLabel);
    const Fat32FsInfo fsInfo = makeFsInfo(layout);
    bootSector.hiddenSectors = qToLittleEndian<quint32>(quint32(partitionOffset / SectorSize));

    DiskFormatError result = writeZeroes(file, partitionOffset, quint64(ReservedSectors) * SectorSize);
    if (result == DiskFormatError::Success)
        result = writeAt(file, partitionOffset,
            reinterpret_cast<const quint8 *>(&bootSector), sizeof(bootSector));
    if (result == DiskFormatError::Success)
        result = writeAt(file, partitionOffset + SectorSize,
            reinterpret_cast<const quint8 *>(&fsInfo), sizeof(fsInfo));
    if (result == DiskFormatError::Success)
        result = writeAt(file, partitionOffset + 6ULL * SectorSize,
            reinterpret_cast<const quint8 *>(&bootSector), sizeof(bootSector));
    if (result == DiskFormatError::Success)
        result = writeAt(file, partitionOffset + 7ULL * SectorSize,
            reinterpret_cast<const quint8 *>(&fsInfo), sizeof(fsInfo));

    const quint64 fatOffset = partitionOffset +
                              static_cast<quint64>(ReservedSectors) * SectorSize;
    const quint64 oneFatBytes = static_cast<quint64>(layout.sectorsPerFat) * SectorSize;
    for (quint8 fat = 0; result == DiskFormatError::Success && fat < FatCount; ++fat)
    {
        const quint64 offset = fatOffset + static_cast<quint64>(fat) * oneFatBytes;
        result = writeZeroes(file, offset, oneFatBytes);
        if (result == DiskFormatError::Success)
        {
            std::array<quint32, SectorSize / sizeof(quint32)> firstSector = {};
            firstSector[0] = qToLittleEndian<quint32>(0x0FFFFFF8);
            firstSector[1] = qToLittleEndian<quint32>(0x0FFFFFFF);
            firstSector[2] = qToLittleEndian<quint32>(0x0FFFFFFF);
            result = writeAt(file, offset,
                reinterpret_cast<const quint8 *>(firstSector.data()), SectorSize);
        }
    }

    if (result == DiskFormatError::Success)
    {
        const quint64 rootOffset = fatOffset +
            static_cast<quint64>(FatCount) * oneFatBytes;
        QByteArray root(int(layout.sectorsPerCluster) * SectorSize, 0);
        std::memcpy(root.data(), bootSector.volumeLabel, 11);
        root[11] = 0x08; // FAT volume label directory entry.
        result = writeAt(file, rootOffset, reinterpret_cast<const quint8 *>(root.constData()), root.size());
    }
    return result;
}

} // namespace

DiskFormatError DiskFormatter::formatFat32(const QString &devicePath,
                                           const QByteArray &volumeLabel)
{
    std::unique_ptr<FileOperations> file = FileOperations::create();
    if (file->openDevice(devicePath, true) != FileError::Success)
        return DiskFormatError::OpenFailed;

    quint64 deviceBytes = 0;
    FatLayout layout;
    if (file->size(deviceBytes) != FileError::Success ||
        !calculateLayout(deviceBytes, layout))
        return DiskFormatError::InvalidSize;

    DiskFormatError result = formatPartition(*file, quint64(PartitionStart) * SectorSize,
                                             layout, volumeLabel);
    if (result == DiskFormatError::Success)
    {
        const std::array<quint8, SectorSize> mbr = makeMbr(layout);
        result = writeAt(*file, 0, mbr.data(), mbr.size());
    }
    if (result == DiskFormatError::Success &&
        file->flush() != FileError::Success)
        result = DiskFormatError::FlushFailed;
    file->close();
    return result;
}

QString DiskFormatter::errorMessage(DiskFormatError error)
{
    switch (error)
    {
    case DiskFormatError::Success: return QString();
    case DiskFormatError::OpenFailed: return QStringLiteral("Could not open the target device");
    case DiskFormatError::InvalidSize: return QStringLiteral("The target is too small or too large for FAT32");
    case DiskFormatError::SeekFailed: return QStringLiteral("Could not seek on the target device");
    case DiskFormatError::WriteFailed: return QStringLiteral("Could not write FAT32 structures");
    case DiskFormatError::FlushFailed: return QStringLiteral("Could not flush the formatted device");
    }
    return QStringLiteral("Unknown formatting error");
}

bool DiskFormatter::relocateGptBackup(char *firstBlock, std::size_t firstBlockSize,
                                      FileOperations &file, quint64 targetSize)
{
    if (!firstBlock || firstBlockSize < 1024)
        return false;

    // GPT Primary Header is at LBA 1 (offset 512)
    const char *primaryHeader = firstBlock + 512;
    if (std::memcmp(primaryHeader, "EFI PART", 8) != 0)
        return false;

    const quint32 headerSize = qFromLittleEndian<quint32>(
        reinterpret_cast<const uchar *>(primaryHeader + 12));
    if (headerSize < 92 || headerSize > 512)
        return false;

    const quint64 myLba = qFromLittleEndian<quint64>(
        reinterpret_cast<const uchar *>(primaryHeader + 24));
    const quint64 currentAltLba = qFromLittleEndian<quint64>(
        reinterpret_cast<const uchar *>(primaryHeader + 32));
    const quint64 firstUsableLba = qFromLittleEndian<quint64>(
        reinterpret_cast<const uchar *>(primaryHeader + 40));
    const quint64 peLba = qFromLittleEndian<quint64>(
        reinterpret_cast<const uchar *>(primaryHeader + 72));
    const quint32 numEntries = qFromLittleEndian<quint32>(
        reinterpret_cast<const uchar *>(primaryHeader + 80));
    const quint32 entrySize = qFromLittleEndian<quint32>(
        reinterpret_cast<const uchar *>(primaryHeader + 84));

    if (myLba != 1 || numEntries == 0 || numEntries > 1024 || entrySize < 128 || entrySize > 512)
        return false;

    const quint64 entriesBytes = static_cast<quint64>(numEntries) * entrySize;
    if (peLba < 2 || (peLba * 512 + entriesBytes) > firstBlockSize)
        return false;

    const quint64 diskSectors = targetSize / 512;
    if (diskSectors <= currentAltLba + 1)
        return false; // Media matches image size or is smaller; no relocation needed.

    const quint64 entriesSectors = (entriesBytes + 511) / 512;
    if (diskSectors <= entriesSectors + 2)
        return false;

    const quint64 newBackupHeaderLba = diskSectors - 1;
    const quint64 newBackupEntriesLba = newBackupHeaderLba - entriesSectors;
    const quint64 newLastUsableLba = newBackupEntriesLba - 1;

    if (newLastUsableLba <= firstUsableLba)
        return false;

    const char *entriesData = firstBlock + (peLba * 512);

    // 1. Prepare and write Backup Partition Entry Array
    if (file.seek(newBackupEntriesLba * 512) != FileError::Success)
        return false;

    std::size_t written = 0;
    if (file.writeSequential(reinterpret_cast<const quint8 *>(entriesData),
                             static_cast<std::size_t>(entriesBytes), written) != FileError::Success ||
        written != entriesBytes)
    {
        return false;
    }

    // Zero-pad to sector boundary if entriesBytes is not sector-aligned
    if (entriesBytes % 512 != 0)
    {
        const std::size_t padBytes = static_cast<std::size_t>(512 - (entriesBytes % 512));
        std::vector<quint8> pad(padBytes, 0);
        std::size_t padWritten = 0;
        if (file.writeSequential(pad.data(), padBytes, padWritten) != FileError::Success)
            return false;
    }

    // 2. Prepare Backup GPT Header
    std::vector<char> backupHeaderBytes(512, 0);
    std::memcpy(backupHeaderBytes.data(), primaryHeader, headerSize);
    char *backupHeader = backupHeaderBytes.data();

    qToLittleEndian<quint64>(newBackupHeaderLba, reinterpret_cast<uchar *>(backupHeader + 24)); // MyLBA
    qToLittleEndian<quint64>(1, reinterpret_cast<uchar *>(backupHeader + 32)); // AlternateLBA
    qToLittleEndian<quint64>(newLastUsableLba, reinterpret_cast<uchar *>(backupHeader + 48)); // LastUsableLBA
    qToLittleEndian<quint64>(newBackupEntriesLba, reinterpret_cast<uchar *>(backupHeader + 72)); // PartitionEntryLBA
    std::memset(backupHeader + 16, 0, 4); // Clear CRC before calculating

    const quint32 backupCrc = openhd_provisioning::crc32(backupHeader, headerSize);
    qToLittleEndian<quint32>(backupCrc, reinterpret_cast<uchar *>(backupHeader + 16));

    if (file.seek(newBackupHeaderLba * 512) != FileError::Success)
        return false;

    written = 0;
    if (file.writeSequential(reinterpret_cast<const quint8 *>(backupHeader), 512, written) != FileError::Success ||
        written != 512)
    {
        return false;
    }

    // 3. Update Primary GPT Header in firstBlock
    char *mutPrimaryHeader = firstBlock + 512;
    qToLittleEndian<quint64>(newBackupHeaderLba, reinterpret_cast<uchar *>(mutPrimaryHeader + 32)); // AlternateLBA
    qToLittleEndian<quint64>(newLastUsableLba, reinterpret_cast<uchar *>(mutPrimaryHeader + 48)); // LastUsableLBA
    std::memset(mutPrimaryHeader + 16, 0, 4); // Clear CRC before calculating

    const quint32 primaryCrc = openhd_provisioning::crc32(mutPrimaryHeader, headerSize);
    qToLittleEndian<quint32>(primaryCrc, reinterpret_cast<uchar *>(mutPrimaryHeader + 16));

    // 4. Update Protective MBR at LBA 0 if present
    if (static_cast<uchar>(firstBlock[450]) == 0xEE)
    {
        const quint32 mbrSectors = static_cast<quint32>(
            std::min<quint64>(diskSectors - 1, 0xFFFFFFFFULL));
        qToLittleEndian<quint32>(mbrSectors, reinterpret_cast<uchar *>(firstBlock + 458));
    }

    if (file.flush() != FileError::Success) return false;
    // Verify the relocated table and header before publishing the primary GPT.
    QByteArray readEntries(int(entriesBytes), 0), readHeader(512, 0);
    std::size_t read = 0;
    if (file.seek(newBackupEntriesLba * 512) != FileError::Success ||
        file.readSequential(reinterpret_cast<quint8 *>(readEntries.data()), entriesBytes, read) != FileError::Success ||
        read != entriesBytes || std::memcmp(readEntries.constData(), entriesData, entriesBytes) != 0 ||
        file.seek(newBackupHeaderLba * 512) != FileError::Success ||
        file.readSequential(reinterpret_cast<quint8 *>(readHeader.data()), 512, read) != FileError::Success ||
        read != 512 || std::memcmp(readHeader.constData(), backupHeader, 512) != 0)
        return false;
    return true;
}


bool DiskFormatter::prepareOpenHDStorage(char *firstBlock, std::size_t firstBlockSize,
                                         FileOperations &file, quint64 imageSize,
                                         quint64 targetSize, QString *error, QStringList *plan,
                                         bool preview, quint64 recordingsSizeBytes)
{
    const auto fail = [error](const QString &message) {
        if (error) *error = message;
        return false;
    };
    if (!firstBlock || firstBlockSize < 512 || imageSize > targetSize)
        return fail(QStringLiteral("Invalid image or target size"));
    if (quint8(firstBlock[510]) != 0x55 || quint8(firstBlock[511]) != 0xaa)
        return recordingsSizeBytes == 0 ||
            fail(QStringLiteral("This image has no adjustable recordings partition"));
    const auto read32 = [](const char *p) {
        return qFromLittleEndian<quint32>(reinterpret_cast<const uchar *>(p));
    };
    const auto read64 = [](const char *p) {
        return qFromLittleEndian<quint64>(reinterpret_cast<const uchar *>(p));
    };
    const auto readAt = [&file, firstBlock, firstBlockSize](quint64 offset, char *data, std::size_t size) {
        if (offset < firstBlockSize && size <= firstBlockSize - offset) {
            std::memcpy(data, firstBlock + offset, size);
            return true;
        }
        if (file.seek(offset) != FileError::Success) return false;
        std::size_t count = 0;
        return file.readSequential(reinterpret_cast<quint8 *>(data), size, count) ==
                   FileError::Success && count == size;
    };
    const bool gpt = firstBlockSize >= 1024 &&
                     std::memcmp(firstBlock + 512, "EFI PART", 8) == 0;
    char *header = gpt ? firstBlock + 512 : nullptr;
    quint32 count = 4, entrySize = 16, headerSize = 0;
    quint64 entriesOffset = 446, firstUsable = 1, lastUsable = targetSize / 512 - 1;
    if (gpt) {
        headerSize = read32(header + 12);
        count = read32(header + 80);
        entrySize = read32(header + 84);
        const quint64 entryLba = read64(header + 72);
        if (headerSize < 92 || headerSize > 512 || !count || count > 1024 ||
            entrySize != 128 || entryLba < 2 || entryLba > firstBlockSize / 512 ||
            entryLba * 512 + quint64(count) * entrySize > firstBlockSize)
            return fail(QStringLiteral("Unsupported GPT layout"));
        entriesOffset = entryLba * 512;
        QByteArray copy(header, int(headerSize));
        std::memset(copy.data() + 16, 0, 4);
        if (openhd_provisioning::crc32(copy.data(), copy.size()) != read32(header + 16) ||
            openhd_provisioning::crc32(firstBlock + entriesOffset, count * entrySize) != read32(header + 88))
            return fail(QStringLiteral("GPT checksum mismatch"));
        firstUsable = read64(header + 40);
        if (read64(header + 24) != 1 ||
            firstUsable < entryLba + (quint64(count) * entrySize + 511) / 512 ||
            read64(header + 48) < firstUsable || read64(header + 48) >= imageSize / 512 ||
            read64(header + 32) >= imageSize / 512)
            return fail(QStringLiteral("Invalid GPT usable sector range"));
        const quint64 tableSectors = (quint64(count) * entrySize + 511) / 512;
        if (targetSize / 512 <= tableSectors + 2)
            return fail(QStringLiteral("Target too small for GPT"));
        lastUsable -= tableSectors + 1;
    } else {
        // Extended partitions and hybrid/protective MBR need their own manifest.
        for (int i = 0; i < 4; ++i) {
            const quint8 type = quint8(firstBlock[446 + 16 * i + 4]);
            if (type == 0x05 || type == 0x0f || type == 0x85 || type == 0xee)
                return recordingsSizeBytes == 0 ||
                    fail(QStringLiteral("This partition table does not support adjustable recordings"));
        }
        lastUsable = std::min<quint64>(lastUsable, 0xffffffffULL);
    }
    struct Partition { quint32 index; quint64 start, end; };
    std::vector<Partition> partitions;
    int freeEntry = -1, recordings = -1;
    bool openhd = false;
    quint64 lastEnd = 0;
    const QByteArray basicData = QByteArray::fromHex("a2a0d0ebe5b9334487c068b6b72699c7");
    for (quint32 i = 0; i < count; ++i) {
        const char *entry = firstBlock + entriesOffset + quint64(i) * entrySize;
        const bool unused = gpt ? QByteArray(entry, 16) == QByteArray(16, 0) : entry[4] == 0;
        if (unused) { if (freeEntry < 0) freeEntry = int(i); continue; }
        const quint64 start = gpt ? read64(entry + 32) : read32(entry + 8);
        const quint64 length = gpt ? 0 : read32(entry + 12);
        const quint64 end = gpt ? read64(entry + 40) : start + length - 1;
        if (start < firstUsable || end < start || end > lastUsable ||
            end >= imageSize / 512 || (!gpt && !length))
            return fail(QStringLiteral("Partition extends outside the image or target"));
        for (const auto &other : partitions)
            if (start <= other.end && end >= other.start)
                return fail(QStringLiteral("Overlapping image partitions"));
        partitions.push_back({i, start, end});
        lastEnd = std::max(lastEnd, end);
        const quint8 type = quint8(entry[4]);
        const bool fatCandidate = gpt ? QByteArray(entry, 16) == basicData :
                                       type == 0x0b || type == 0x0c || type == 0x0e || type == 0x06;
        QString name;
        if (gpt) {
            for (int c = 0; c < 36; ++c) {
                const quint16 value = qFromLittleEndian<quint16>(reinterpret_cast<const uchar *>(entry + 56 + c * 2));
                if (!value) break;
                name.append(QChar(value));
            }
            if (name.isEmpty()) {
                const QByteArray type(entry, 16);
                if (type == QByteArray::fromHex("28732ac11ff8d211ba4b00a0c93ec93b")) name = QStringLiteral("EFI boot");
                else if (type == QByteArray::fromHex("4861682149646f6e744e656564454649")) name = QStringLiteral("BIOS boot");
                else if (type == QByteArray::fromHex("af3dc60f838472478e793d69d8477de4")) name = QStringLiteral("Linux filesystem");
            }
        }
        if (plan) plan->append(QStringLiteral("Partition %1%2: %3 MiB, sectors %4-%5; kept from image")
            .arg(i + 1).arg(name.isEmpty() ? QString() : QStringLiteral(" - ") + name)
            .arg(double(end - start + 1) / 2048.0, 0, 'f', 1).arg(start).arg(end));
        if (!fatCandidate) continue;
        QByteArray boot(512, 0);
        if (!readAt(start * 512, boot.data(), 512))
            return fail(QStringLiteral("Could not read image filesystem metadata"));
        if (quint8(boot[510]) != 0x55 || quint8(boot[511]) != 0xaa ||
            qFromLittleEndian<quint16>(reinterpret_cast<const uchar *>(boot.constData() + 11)) != 512)
            continue;
        const bool fat32 = boot.mid(82, 8) == "FAT32   ";
        const QByteArray label = boot.mid(fat32 ? 71 : 43, 11).trimmed().toUpper();
        if (label == "OPENHD") openhd = true;
        if (fat32 && label == "RECORDINGS") {
            if (recordings >= 0) return fail(QStringLiteral("Multiple recordings partitions"));
            recordings = int(partitions.size()) - 1;
        }
    }
    if (!openhd) {
        if (plan) plan->append(QStringLiteral("No OPENHD config volume detected; no automatic recordings partition will be created."));
        return recordingsSizeBytes == 0 ||
            fail(QStringLiteral("The OPENHD configuration volume required for recordings is missing"));
    }
    quint64 start = 0;
    int selectedEntry = -1;
    if (recordings >= 0) {
        const auto &part = partitions[std::size_t(recordings)];
        if (part.end != lastEnd || (recordingsSizeBytes == 0 && part.end == lastUsable)) {
            if (plan) plan->append(QStringLiteral("Existing RECORDINGS partition kept at its image size."));
            return recordingsSizeBytes == 0 ||
                fail(QStringLiteral("The existing recordings partition cannot be resized"));
        }
        start = part.start;
        selectedEntry = int(part.index);
    } else {
        // The image contains boot/config data, but no recordings partition.
        // Append after the complete image, including any old backup GPT.
        start = ((std::max(lastEnd + 1, (imageSize + 511) / 512) + 2047) / 2048) * 2048;
        if (start > lastUsable || lastUsable - start + 1 < 131072)
            return fail(QStringLiteral("Not enough unallocated space for recording storage (at least 64 MiB required)"));
        if (freeEntry < 0) return fail(QStringLiteral("No free partition entry for recording storage"));
        selectedEntry = freeEntry;
    }
    const quint64 availableSectors = lastUsable - start + 1;
    quint64 sectors = availableSectors;
    if (recordingsSizeBytes > 0) {
        const quint64 requestedSectors = recordingsSizeBytes / 512;
        if (requestedSectors < 131072 || requestedSectors > availableSectors)
            return fail(QStringLiteral("Manual recordings size must be at least 64 MiB and fit in the available space"));
        // Keep the same 1 MiB alignment used for partition starts.
        sectors = (requestedSectors / 2048) * 2048;
        if (sectors < 131072)
            return fail(QStringLiteral("Manual recordings size is too small after alignment"));
    }
    const quint64 recordingsEnd = start + sectors - 1;
    if (start > 0xffffffffULL || sectors > 0xffffffffULL)
        return fail(QStringLiteral("Recording storage exceeds supported FAT32 geometry"));
    FatLayout layout;
    if (!calculateLayout((start + sectors) * 512, layout, quint32(start)) || layout.totalSectors != sectors)
        return fail(QStringLiteral("Recording partition cannot be represented as FAT32"));
    if (plan) plan->append(QStringLiteral("%1 partition %2 - RECORDINGS (FAT32): %3 GiB, sectors %4-%5")
        .arg(recordings < 0 ? QStringLiteral("Create") : QStringLiteral("Expand"))
        .arg(selectedEntry + 1).arg(double(sectors) * 512.0 / (1024.0 * 1024.0 * 1024.0), 0, 'f', 2)
        .arg(start).arg(recordingsEnd));
    if (preview) return true;
    const auto formatted = formatPartition(file, start * 512, layout, QByteArray("RECORDINGS"));
    if (formatted != DiskFormatError::Success) return fail(errorMessage(formatted));
    if (file.flush() != FileError::Success)
        return fail(QStringLiteral("Could not flush recording filesystem"));
    // Read back all structures produced by the formatter, including both FATs.
    auto expectedBoot = makeBootSector(layout, QByteArray("RECORDINGS"));
    expectedBoot.hiddenSectors = qToLittleEndian<quint32>(quint32(start));
    const auto expectedInfo = makeFsInfo(layout);
    QByteArray actual(512, 0);
    for (const quint64 sector : {0ULL, 6ULL})
        if (!readAt((start + sector) * 512, actual.data(), 512) ||
            std::memcmp(actual.data(), &expectedBoot, 512))
            return fail(QStringLiteral("Recording boot-sector verification failed"));
    for (const quint64 sector : {1ULL, 7ULL})
        if (!readAt((start + sector) * 512, actual.data(), 512) ||
            std::memcmp(actual.data(), &expectedInfo, 512))
            return fail(QStringLiteral("Recording FSInfo verification failed"));
    const quint64 fatSectors = quint64(FatCount) * layout.sectorsPerFat;
    QByteArray expected(512, 0);
    qToLittleEndian<quint32>(0x0ffffff8, reinterpret_cast<uchar *>(expected.data()));
    qToLittleEndian<quint32>(0x0fffffff, reinterpret_cast<uchar *>(expected.data() + 4));
    qToLittleEndian<quint32>(0x0fffffff, reinterpret_cast<uchar *>(expected.data() + 8));
    // Batch readback to avoid thousands of tiny SD-reader transfers.
    for (quint64 sector = 0; sector < fatSectors;) {
        const quint64 sectors = std::min<quint64>(2048, fatSectors - sector);
        QByteArray buffer(int(sectors * 512), 0), wanted(buffer.size(), 0);
        for (quint64 i = 0; i < sectors; ++i)
            if ((sector + i) % layout.sectorsPerFat == 0)
                std::memcpy(wanted.data() + i * 512, expected.constData(), 512);
        if (!readAt((start + ReservedSectors + sector) * 512, buffer.data(), buffer.size()) || buffer != wanted)
            return fail(QStringLiteral("Recording FAT verification failed"));
        sector += sectors;
    }
    QByteArray root(int(layout.sectorsPerCluster) * 512, 0), expectedRoot(root.size(), 0);
    std::memcpy(expectedRoot.data(), expectedBoot.volumeLabel, 11);
    expectedRoot[11] = 0x08;
    if (!readAt((start + ReservedSectors + fatSectors) * 512, root.data(), root.size()) || root != expectedRoot)
        return fail(QStringLiteral("Recording root-directory verification failed"));
    char *entry = firstBlock + entriesOffset + quint64(selectedEntry) * entrySize;
    if (gpt) {
        if (recordings < 0) {
            std::memset(entry, 0, entrySize);
            std::memcpy(entry, basicData.constData(), 16);
            // QUuid RFC bytes are a unique opaque identifier for this partition.
            const QByteArray uuid = QUuid::createUuid().toRfc4122();
            std::memcpy(entry + 16, uuid.constData(), 16);
            const QString name = QStringLiteral("recordings");
            for (int i = 0; i < name.size(); ++i)
                qToLittleEndian<quint16>(name[i].unicode(), reinterpret_cast<uchar *>(entry + 56 + 2 * i));
        }
        qToLittleEndian<quint64>(start, reinterpret_cast<uchar *>(entry + 32));
        qToLittleEndian<quint64>(recordingsEnd, reinterpret_cast<uchar *>(entry + 40));
        qToLittleEndian<quint32>(openhd_provisioning::crc32(firstBlock + entriesOffset, count * entrySize),
                                reinterpret_cast<uchar *>(header + 88));
        // Force relocation to publish the modified array and both header CRCs,
        // even when the original image already described the entire target.
        qToLittleEndian<quint64>(targetSize / 512 - 2, reinterpret_cast<uchar *>(header + 32));
        if (!relocateGptBackup(firstBlock, firstBlockSize, file, targetSize))
            return fail(QStringLiteral("Could not publish recording GPT backup"));
    } else {
        MbrPartitionEntry part = {};
        part.partitionType = 0x0c;
        part.firstHead = part.lastHead = 0xfe;
        part.firstSector = part.lastSector = part.firstCylinder = part.lastCylinder = 0xff;
        part.firstLba = qToLittleEndian<quint32>(quint32(start));
        part.sectorCount = qToLittleEndian<quint32>(quint32(sectors));
        std::memcpy(entry, &part, sizeof(part));
    }
    return file.flush() == FileError::Success || fail(QStringLiteral("Could not flush storage metadata"));
}
