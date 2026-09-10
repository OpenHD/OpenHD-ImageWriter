/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include "diskformatter.h"
#include "file_operations.h"

#include <QtEndian>

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
        if (calculated == current) return current;
        current = calculated;
    }
    return current;
}

bool calculateLayout(quint64 deviceBytes, FatLayout &layout)
{
    const quint64 deviceSectors = deviceBytes / SectorSize;
    if (deviceSectors <= PartitionStart + ReservedSectors)
        return false;
    const quint64 usable = std::min<quint64>(
        deviceSectors, std::numeric_limits<quint32>::max()) - PartitionStart;
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
    std::memcpy(mbr.data() + 446, &partition, sizeof(partition));
    mbr[510] = 0x55;
    mbr[511] = 0xAA;
    return mbr;
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

    const Fat32BootSector bootSector = makeBootSector(layout, volumeLabel);
    const Fat32FsInfo fsInfo = makeFsInfo(layout);
    const quint64 partitionOffset = static_cast<quint64>(PartitionStart) * SectorSize;

    DiskFormatError result = writeAt(*file, partitionOffset,
        reinterpret_cast<const quint8 *>(&bootSector), sizeof(bootSector));
    if (result == DiskFormatError::Success)
        result = writeAt(*file, partitionOffset + SectorSize,
            reinterpret_cast<const quint8 *>(&fsInfo), sizeof(fsInfo));
    if (result == DiskFormatError::Success)
        result = writeAt(*file, partitionOffset + 6ULL * SectorSize,
            reinterpret_cast<const quint8 *>(&bootSector), sizeof(bootSector));
    if (result == DiskFormatError::Success)
        result = writeAt(*file, partitionOffset + 7ULL * SectorSize,
            reinterpret_cast<const quint8 *>(&fsInfo), sizeof(fsInfo));

    const quint64 fatOffset = partitionOffset +
                              static_cast<quint64>(ReservedSectors) * SectorSize;
    const quint64 oneFatBytes = static_cast<quint64>(layout.sectorsPerFat) * SectorSize;
    for (quint8 fat = 0; result == DiskFormatError::Success && fat < FatCount; ++fat)
    {
        const quint64 offset = fatOffset + static_cast<quint64>(fat) * oneFatBytes;
        result = writeZeroes(*file, offset, oneFatBytes);
        if (result == DiskFormatError::Success)
        {
            std::array<quint32, SectorSize / sizeof(quint32)> firstSector = {};
            firstSector[0] = qToLittleEndian<quint32>(0x0FFFFFF8);
            firstSector[1] = qToLittleEndian<quint32>(0x0FFFFFFF);
            firstSector[2] = qToLittleEndian<quint32>(0x0FFFFFFF);
            result = writeAt(*file, offset,
                reinterpret_cast<const quint8 *>(firstSector.data()), SectorSize);
        }
    }

    if (result == DiskFormatError::Success)
    {
        const quint64 rootOffset = fatOffset +
            static_cast<quint64>(FatCount) * oneFatBytes;
        result = writeZeroes(*file, rootOffset,
                             static_cast<quint64>(layout.sectorsPerCluster) * SectorSize);
    }
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
