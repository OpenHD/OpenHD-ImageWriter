// SPDX-License-Identifier: Apache-2.0
#include "rockchipconfiguration.h"
#include "fatimagewriter.h"
#include "openhdprovisioning.h"
#include <QFile>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QtEndian>
#include <QSet>
#include <cstring>

namespace {
quint32 le32(const QByteArray &data, int pos) { return qFromLittleEndian<quint32>(reinterpret_cast<const uchar *>(data.constData() + pos)); }
quint64 le64(const QByteArray &data, int pos) { return qFromLittleEndian<quint64>(reinterpret_cast<const uchar *>(data.constData() + pos)); }
quint32 be32(const QByteArray &data, int pos) { return qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(data.constData() + pos)); }
void putBe(QByteArray &data, int pos, quint32 value) { qToBigEndian<quint32>(value, reinterpret_cast<uchar *>(data.data() + pos)); }
quint32 crc(const QByteArray &data) { return openhd_provisioning::crc32(data.constData(), data.size()); }
bool fail(QString *error, const QString &detail) { if (error) *error = detail; return false; }
bool readAt(QFile &file, qint64 offset, qint64 size, QByteArray &data) {
    if (offset < 0 || size < 0 || offset > file.size() || size > file.size() - offset || !file.seek(offset)) return false;
    data = file.read(size); return data.size() == size;
}
bool gptHeader(QFile &file, quint64 lba, QByteArray &header, QByteArray &entries) {
    if (!readAt(file, lba * 512, 512, header) || header.left(8) != "EFI PART") return false;
    const auto size = le32(header, 12), count = le32(header, 80), stride = le32(header, 84);
    if (size < 92 || size > 512 || !count || count > 4096 || stride < 128 || stride > 1024 ||
        quint64(count) * stride > 1024 * 1024 || le64(header, 24) != lba) return false;
    QByteArray checked = header.left(size);
    const quint32 expected = le32(header, 16);
    std::memset(checked.data() + 16, 0, 4);
    const auto entryLba = le64(header, 72);
    return crc(checked) == expected && entryLba < quint64(file.size() / 512) &&
        readAt(file, entryLba * 512, quint64(count) * stride, entries) && crc(entries) == le32(header, 88);
}
}

bool RockchipConfiguration::installDisk(const QString &imagePath, const QString &staging,
                                        QString *error, const std::function<bool()> &cancelled)
{
    QFile file(imagePath);
    if (!QFileInfo(imagePath).isFile() || !file.open(QIODevice::ReadOnly) || file.size() % 512)
        return fail(error, "Cannot open the extracted GPT disk image.");
    QByteArray header, entries, backup, backupEntries;
    if (!gptHeader(file, 1, header, entries) || le64(header, 32) != quint64(file.size() / 512 - 1) ||
        !gptHeader(file, le64(header, 32), backup, backupEntries) || entries != backupEntries ||
        le64(backup, 32) != 1 || header.mid(40, 32) != backup.mid(40, 32))
        return fail(error, "The image GPT headers or partition checksums are invalid.");
    const auto stride = le32(header, 84);
    quint64 configFirst = 0, configLast = 0;
    QList<QPair<quint64, quint64>> extents;
    int matches = 0;
    const QByteArray basicData = QByteArray::fromHex("a2a0d0ebe5b9334487c068b6b72699c7");
    for (int pos = 0; pos < entries.size(); pos += stride) {
        if (entries.mid(pos, 16) == QByteArray(16, '\0')) continue;
        const auto first = le64(entries, pos + 32), last = le64(entries, pos + 40);
        if (first < le64(header, 40) || last > le64(header, 48) || last < first || last >= quint64(file.size() / 512))
            return fail(error, "GPT partition lies outside the image.");
        for (const auto &extent : extents) if (first <= extent.second && last >= extent.first)
            return fail(error, "GPT partitions overlap.");
        extents.append({first, last});
        QString name;
        for (int i = 0; i < 36; ++i) {
            const auto ch = qFromLittleEndian<quint16>(reinterpret_cast<const uchar *>(entries.constData() + pos + 56 + i * 2));
            if (!ch) break;
            name += QChar(ch);
        }
        if (name == "ohd_config") {
            if (entries.mid(pos, 16) != basicData) return fail(error, "Config partition has an unexpected GPT type.");
            ++matches; configFirst = first; configLast = last;
        }
    }
    if (matches != 1) return fail(error, "Expected exactly one ohd_config partition in the Luckfox GPT image.");
    file.close();
    return FatImageWriter::install(imagePath, staging, error, cancelled, configFirst * 512, (configLast - configFirst + 1) * 512);
}

bool RockchipConfiguration::installUbi(const QString &imagePath, const QString &staging,
                                       QString *error, const std::function<bool()> &cancelled)
{
    // X21 provisioning is a reserved static volume. UBIFS/application PEBs and
    // both volume tables remain byte-for-byte unchanged. UBI CRC convention is
    // Linux crc32_le(~0, ...) without the usual final xor.
    constexpr int pebSize = 131072, vidOffset = 2048, dataOffset = 4096, lebSize = 126976;
    constexpr quint32 layoutVolume = 0x7fffefff;
    QFile image(imagePath);
    if (!QFileInfo(imagePath).isFile() || !image.open(QIODevice::ReadWrite) ||
        image.size() != 100LL * 1024 * 1024)
        return fail(error, "Expected a padded 100 MiB X21 OHD UBI image.");
    QList<int> reusable, provisionBlocks;
    QByteArray ecTemplate, record, table;
    quint32 sequence = 0;
    int layoutCopies = 0;
    QSet<quint32> layoutNumbers, provisionNumbers;
    quint32 usedEbs = 0;
    for (int index = 0; index < image.size() / pebSize; ++index) {
        if (cancelled && cancelled()) return fail(error, "Cancelled.");
        QByteArray block;
        if (!readAt(image, qint64(index) * pebSize, pebSize, block)) return fail(error, "Cannot read UBI eraseblock.");
        if (block == QByteArray(pebSize, char(0xff))) { reusable.append(index); continue; }
        const auto ec = block.left(64), vid = block.mid(vidOffset, 64);
        if (ec.left(4) != "UBI#" || uchar(ec[4]) != 1 || be32(ec, 16) != vidOffset || be32(ec, 20) != dataOffset ||
            (crc(ec.left(60)) ^ 0xffffffffU) != be32(ec, 60) || vid.left(4) != "UBI!" || uchar(vid[4]) != 1 ||
            (crc(vid.left(60)) ^ 0xffffffffU) != be32(vid, 60))
            return fail(error, "Invalid or unsupported X21 UBI headers.");
        if (ecTemplate.isEmpty()) { ecTemplate = ec; sequence = be32(ec, 24); }
        if (be32(ec, 24) != sequence) return fail(error, "Mixed UBI image sequences.");
        const auto volume = be32(vid, 8), lnum = be32(vid, 12);
        if (volume == layoutVolume) {
            if (uchar(vid[5]) != 1 || lnum > 1 || layoutNumbers.contains(lnum))
                return fail(error, "Ambiguous UBI volume table.");
            layoutNumbers.insert(lnum);
            const auto currentTable = block.mid(dataOffset, 128 * 172);
            if (!table.isEmpty() && table != currentTable) return fail(error, "UBI volume tables differ.");
            table = currentTable;
            for (int i = 0; i < 128; ++i) {
                const auto item = table.mid(i * 172, 172);
                if ((crc(item.left(168)) ^ 0xffffffffU) != be32(item, 168))
                    return fail(error, "Invalid UBI volume table checksum.");
                if (i > 1 && be32(item, 0)) return fail(error, "Unexpected reserved UBI volume.");
            }
            const auto application = table.left(172);
            if (!be32(application, 0) || be32(application, 0) > 760 ||
                uchar(application[12]) != 1 || application[13] ||
                application[14] || uchar(application[15]) != 3 || application.mid(16, 3) != "ohd")
                return fail(error, "Unexpected application volume or insufficient UBI reserve.");
            record = table.mid(172, 172);
            const auto nameLength = qFromBigEndian<quint16>(reinterpret_cast<const uchar *>(record.constData() + 14));
            if (be32(record, 0) != 16 || be32(record, 4) != 1 || be32(record, 8) != 0 ||
                uchar(record[12]) != 2 || record[13] || nameLength != 16 || record.mid(16, nameLength) != "openhd-provision" || record[144])
                return fail(error, "X21 image has no compatible provisioning volume. Use a new full firmware image.");
            ++layoutCopies;
        } else if (volume == 1) {
            const auto size = be32(vid, 20), used = be32(vid, 24);
            if (uchar(vid[5]) != 2 || vid[6] || vid[7] || !used || used > 16 || lnum >= used ||
                provisionNumbers.contains(lnum) || size > lebSize || !size || be32(vid, 28) ||
                (lnum + 1 < used && size != lebSize) || (usedEbs && usedEbs != used) ||
                (crc(block.mid(dataOffset, size)) ^ 0xffffffffU) != be32(vid, 32))
                return fail(error, "Invalid static provisioning volume data.");
            usedEbs = used; provisionNumbers.insert(lnum); provisionBlocks.append(index);
        } else if (volume != 0 || uchar(vid[5]) != 1 || be32(vid, 28))
            return fail(error, "Unexpected UBI volume; image was not modified.");
    }
    if (layoutCopies != 2 || !usedEbs || provisionBlocks.size() != int(usedEbs))
        return fail(error, "Incomplete X21 provisioning volume.");
    std::vector<openhd_provisioning::File> files;
    QDir root(staging);
    QDirIterator iterator(staging, QDir::Files | QDir::Hidden | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        if (cancelled && cancelled()) return fail(error, "Cancelled.");
        QFile input(iterator.next());
        if (iterator.fileInfo().isSymLink() || input.size() > qint64(openhd_provisioning::max_size) || !input.open(QIODevice::ReadOnly))
            return fail(error, "Cannot read staged provisioning file.");
        const auto bytes = input.readAll();
        if (bytes.size() != input.size()) return fail(error, "Incomplete staged provisioning file.");
        files.push_back({root.relativeFilePath(input.fileName()).toUtf8().toStdString(), bytes.toStdString()});
    }
    const auto encoded = openhd_provisioning::encode(files);
    if (encoded.empty()) return fail(error, "X21 provisioning exceeds its 1984 KiB reservation or contains unsupported paths. Remove the offline map or select a smaller one.");
    const QByteArray capsule = QByteArray::fromStdString(encoded);
    const int blocks = (capsule.size() + lebSize - 1) / lebSize;
    const int oldCount = provisionBlocks.size();
    provisionBlocks.append(reusable);
    if (provisionBlocks.size() < blocks) return fail(error, "Insufficient erased space for X21 provisioning.");
    for (int i = 0; i < qMax(oldCount, blocks); ++i) {
        if (cancelled && cancelled()) return fail(error, "Cancelled.");
        QByteArray block(pebSize, char(0xff));
        if (i < blocks) {
            QByteArray ec = ecTemplate;
            // Retain the package's image sequence, reset erase counter for a new image.
            std::memset(ec.data() + 8, 0, 8);
            putBe(ec, 60, crc(ec.left(60)) ^ 0xffffffffU);
            QByteArray vid(64, '\0');
            vid.replace(0, 4, "UBI!"); vid[4] = 1; vid[5] = 2;
            const auto data = capsule.mid(i * lebSize, lebSize);
            putBe(vid, 8, 1); putBe(vid, 12, i); putBe(vid, 20, data.size()); putBe(vid, 24, blocks);
            putBe(vid, 32, crc(data) ^ 0xffffffffU); putBe(vid, 60, crc(vid.left(60)) ^ 0xffffffffU);
            block.replace(0, 64, ec); block.replace(vidOffset, 64, vid); block.replace(dataOffset, data.size(), data);
        }
        const auto offset = qint64(provisionBlocks.at(i)) * pebSize;
        if (!image.seek(offset) || image.write(block) != block.size() || !image.flush())
            return fail(error, "Cannot save provisioning eraseblock.");
        QByteArray readback;
        if (!readAt(image, offset, pebSize, readback) || readback != block)
            return fail(error, "Provisioning eraseblock readback failed.");
    }
    return true;
}
