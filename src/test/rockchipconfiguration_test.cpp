// SPDX-License-Identifier: Apache-2.0
#include "rockchipconfiguration.h"
#include "openhdprovisioning.h"
#include <QFile>
#include <QDir>
#include <QTemporaryDir>
#include <QCryptographicHash>
#include <QtEndian>
#include <cstdio>
#include <cstring>

namespace {
void be(QByteArray &data, int at, quint32 value) { qToBigEndian<quint32>(value, reinterpret_cast<uchar *>(data.data() + at)); }
void le(QByteArray &data, int at, quint32 value) { qToLittleEndian<quint32>(value, reinterpret_cast<uchar *>(data.data() + at)); }
void le64(QByteArray &data, int at, quint64 value) { qToLittleEndian<quint64>(value, reinterpret_cast<uchar *>(data.data() + at)); }
quint32 crc(const QByteArray &data) { return openhd_provisioning::crc32(data.constData(), data.size()); }
QByteArray ec() {
    QByteArray header(64, '\0'); header.replace(0, 4, "UBI#"); header[4] = 1;
    be(header, 16, 2048); be(header, 20, 4096); be(header, 24, 123);
    be(header, 60, crc(header.left(60)) ^ 0xffffffffU); return header;
}
QByteArray block(quint32 volume, quint32 number, const QByteArray &data, bool isStatic) {
    QByteArray out(131072, char(0xff)), vid(64, '\0');
    vid.replace(0, 4, "UBI!"); vid[4] = 1; vid[5] = isStatic ? 2 : 1;
    if (volume == 0x7fffefff) vid[7] = 5;
    be(vid, 8, volume); be(vid, 12, number);
    if (isStatic) { be(vid, 20, data.size()); be(vid, 24, 1); be(vid, 32, crc(data) ^ 0xffffffffU); }
    be(vid, 60, crc(vid.left(60)) ^ 0xffffffffU);
    out.replace(0, 64, ec()); out.replace(2048, 64, vid); out.replace(4096, data.size(), data); return out;
}
bool write(const QString &path, const QByteArray &data) {
    QFile output(path); return output.open(QIODevice::WriteOnly) && output.write(data) == data.size();
}
QByteArray hash(const QString &path) {
    QFile input(path); if (!input.open(QIODevice::ReadOnly)) return {};
    QCryptographicHash hash(QCryptographicHash::Sha256); hash.addData(&input); return hash.result();
}
bool check(bool value, const QString &detail) {
    if (!value) std::fprintf(stderr, "%s\n", qPrintable(detail));
    return value;
}
}

bool testRockchipConfiguration(const QString &fatImage, const QString &staging)
{
    QTemporaryDir temporary;
    if (!write(QDir(staging).filePath("openhd/maps/multiple-lebs.glidemap"), QByteArray(270000, 'v'))) return false;
    // Minimal complete GPT disk containing the independently exercised FAT image.
    QFile fat(fatImage); if (!fat.open(QIODevice::ReadOnly)) return false;
    const QByteArray fatBytes = fat.readAll();
    QByteArray disk(8 * 1024 * 1024, char(0xa5));
    const quint64 sectors = disk.size() / 512;
    disk[510] = 0x55; disk[511] = char(0xaa);
    QByteArray entries(128 * 128, '\0');
    entries.replace(0, 16, QByteArray::fromHex("a2a0d0ebe5b9334487c068b6b72699c7"));
    le64(entries, 32, 2048); le64(entries, 40, 2048 + fatBytes.size() / 512 - 1);
    const QString name = "ohd_config";
    for (int i = 0; i < name.size(); ++i) qToLittleEndian<quint16>(name.at(i).unicode(), reinterpret_cast<uchar *>(entries.data() + 56 + i * 2));
    for (bool backup : {false, true}) {
        QByteArray header(512, '\0'); header.replace(0, 8, "EFI PART");
        le(header, 8, 0x10000); le(header, 12, 92); le64(header, 24, backup ? sectors - 1 : 1);
        le64(header, 32, backup ? 1 : sectors - 1); le64(header, 40, 34); le64(header, 48, sectors - 34);
        le64(header, 72, backup ? sectors - 33 : 2); le(header, 80, 128); le(header, 84, 128);
        le(header, 88, crc(entries)); le(header, 16, crc(header.left(92)));
        disk.replace((backup ? sectors - 1 : 1) * 512, 512, header);
        disk.replace((backup ? sectors - 33 : 2) * 512, entries.size(), entries);
    }
    disk.replace(2048 * 512, fatBytes.size(), fatBytes);
    const QString diskPath = temporary.filePath("disk.img");
    if (!write(diskPath, disk)) return false;
    QString error;
    if (!check(RockchipConfiguration::installDisk(diskPath, staging, &error), "GPT config install failed: " + error)) return false;
    QFile result(diskPath); if (!result.open(QIODevice::ReadOnly)) return false;
    const auto updated = result.readAll(); result.close();
    const int after = 2048 * 512 + fatBytes.size();
    if (!check(updated.left(2048 * 512) == disk.left(2048 * 512) && updated.mid(after) == disk.mid(after),
               "FAT update changed bytes outside the selected GPT partition")) return false;
    auto corrupt = disk; corrupt[512 + 16] = char(corrupt.at(512 + 16) ^ 1);
    if (!write(diskPath, corrupt)) return false;
    const auto before = hash(diskPath);
    if (!check(!RockchipConfiguration::installDisk(diskPath, staging, &error) && hash(diskPath) == before,
               "Corrupt GPT was modified")) return false;

    const QString ubiPath = temporary.filePath("ohd.img");
    QByteArray table(128 * 172, '\0');
    be(table, 0, 10); be(table, 4, 1); table[12] = 1; table[15] = 3; table.replace(16, 3, "ohd"); table[144] = 1;
    be(table, 172, 16); be(table, 176, 1); table[172 + 12] = 2; table[172 + 15] = 16;
    table.replace(172 + 16, 16, "openhd-provision");
    for (int i = 0; i < 128; ++i) be(table, i * 172 + 168, crc(table.mid(i * 172, 168)) ^ 0xffffffffU);
    const auto first = block(0x7fffefff, 0, table, false) + block(0x7fffefff, 1, table, false) + block(0, 0, "UBIFS application data must be preserved", false);
    QFile ubi(ubiPath); if (!ubi.open(QIODevice::WriteOnly)) return false;
    if (ubi.write(first) != first.size()) return false;
    const auto empty = QByteArray::fromStdString(openhd_provisioning::encode({}));
    ubi.write(block(1, 0, empty, true));
    for (int i = 4; i < 800; ++i) ubi.write(QByteArray(131072, char(0xff)));
    ubi.close();
    if (!check(RockchipConfiguration::installUbi(ubiPath, staging, &error), "UBI config install failed: " + error)) return false;
    if (!ubi.open(QIODevice::ReadOnly)) return false;
    if (!check(ubi.read(first.size()) == first, "UBI table or application PEBs were changed")) return false;
    QByteArray capsule;
    for (int i = 3; i < 800; ++i) {
        ubi.seek(qint64(i) * 131072);
        const auto data = ubi.read(131072);
        if (data.left(4) != "UBI#") continue;
        const auto vid = data.mid(2048, 64);
        if (qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(vid.constData() + 8)) != 1) continue;
        const auto size = qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(vid.constData() + 20));
        capsule += data.mid(4096, size);
    }
    ubi.close();
    std::vector<openhd_provisioning::File> decoded;
    bool largeFileFound = false;
    if (!check(openhd_provisioning::decode(capsule.toStdString(), decoded), "UBI capsule readback failed")) return false;
    for (const auto &item : decoded) if (item.path == "openhd/maps/multiple-lebs.glidemap")
        largeFileFound = item.data == std::string(270000, 'v');
    if (!check(largeFileFound, "Multi-LEB file contents changed")) return false;
    const auto stable = hash(ubiPath);
    if (!check(!RockchipConfiguration::installUbi(ubiPath, staging, &error, [] { return true; }) && hash(ubiPath) == stable,
               "Cancelled UBI preparation changed the image")) return false;
    if (!write(QDir(staging).filePath("openhd/maps/oversized.glidemap"), QByteArray(3 * 1024 * 1024, 'x'))) return false;
    if (!check(!RockchipConfiguration::installUbi(ubiPath, staging, &error) && hash(ubiPath) == stable,
               "Oversized provisioning changed the UBI image")) return false;
    QFile::remove(QDir(staging).filePath("openhd/maps/oversized.glidemap"));
    if (!ubi.open(QIODevice::ReadWrite) || !ubi.seek(60) || ubi.write("\0", 1) != 1) return false;
    ubi.close();
    const auto corruptedUbi = hash(ubiPath);
    if (!check(!RockchipConfiguration::installUbi(ubiPath, staging, &error) && hash(ubiPath) == corruptedUbi,
               "Corrupt UBI headers were modified")) return false;
    return check(openhd_provisioning::crc32("123456789", 9) == 0xcbf43926U, "CRC32 standard vector failed");
}
