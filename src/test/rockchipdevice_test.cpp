/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "rockchipdevice.h"
#include "rockchipimageverify.h"
#include <QBuffer>
#include <cstring>

#ifdef Q_OS_WIN
#include <initguid.h>
#include <usbiodef.h>
#endif

#include <QCoreApplication>
#include <QDebug>
#include <QTextStream>
#include <QtEndian>

static bool testImageReadback()
{
    QByteArray image(65536 + 513, 'x');
    QBuffer source(&image);
    source.open(QIODevice::ReadOnly);
    QByteArray disk = image;
    disk.append(QByteArray(511, '\0'));
    QString error;
    int reads = 0;
    auto read = [&](quint32 lba, quint16 sectors, quint8 *data, QString *) {
        ++reads;
        const int offset = (lba - 17) * 512;
        if (offset < 0 || offset + sectors * 512 > disk.size()) return false;
        memcpy(data, disk.constData() + offset, sectors * 512);
        return true;
    };
    auto verify = [&](quint64 size) {
        source.seek(0);
        return verifyRockchipImage(source, size, 17, read, []() { return false; }, &error);
    };
    if (!verify(image.size()) || reads != 2) return false;
    // A corruption after the first 64 KiB must be caught.
    disk[65536] = 'z';
    if (verify(image.size()) || !error.contains("mismatch")) return false;
    disk[65536] = 'x';
    // Verification includes padding, not just bytes in the source file.
    disk[disk.size() - 1] = 'z';
    if (verify(image.size())) return false;
    disk[disk.size() - 1] = '\0';
    if (verify(image.size() + 1) || !error.contains("source")) return false;
    source.seek(0);
    if (verifyRockchipImage(source, image.size(), 17,
            [](quint32, quint16, quint8 *, QString *message) {
                *message = "USB read failure"; return false;
            }, []() { return false; }, &error) || error != "USB read failure") return false;
    reads = 0;
    source.seek(0);
    if (verifyRockchipImage(source, image.size(), 17, read,
            []() { return true; }, &error) || reads || !error.isEmpty()) return false;
    return !verify(0);
}

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    if (application.arguments().contains(QStringLiteral("--list-devices")))
    {
        QTextStream output(stdout);
        for (const auto &device : listRockchipUsbDevices())
            output << device.id << " " << device.socName << " bcdUSB="
                   << QString::number(device.bcdUsb, 16) << " MaskROM="
                   << device.isMaskrom << Qt::endl;
        return 0;
    }

    QByteArray rv1106(102, '\0');
    rv1106.replace(0, 4, "LDR ");
    qToLittleEndian<quint32>(0x31313036, reinterpret_cast<uchar *>(rv1106.data() + 21));
    QByteArray rv1126b = rv1106;
    qToLittleEndian<quint32>(0x31313046, reinterpret_cast<uchar *>(rv1126b.data() + 21));

    const bool passed = testImageReadback() &&
            rockchipSocName(0x2207, 0x110c) == QStringLiteral("RV1106 / RV1103") &&
            rockchipSocName(0x2207, 0x110f) == QStringLiteral("RV1126B") &&
            !rockchipIsLoaderMode(0x110c, 0x0200, false, false) &&
            !rockchipIsLoaderMode(0x110c, 0x0200, true, false) &&
            !rockchipIsLoaderMode(0x110c, 0x0200, false, true) &&
            rockchipIsLoaderMode(0x110c, 0x0200, true, true) &&
            rockchipIsLoaderMode(0x110f, 0x0200, true, true) &&
            rockchipIsLoaderMode(0x110f, 0x0200, true, false) &&
            rockchipIsLoaderMode(0x110b, 0x0201, false, false) &&
            !rockchipIsLoaderMode(0x110b, 0x0200, true, true) &&
            rockchipLoaderMatchesDevice(rv1106, 0x2207, 0x110c) &&
            rockchipLoaderMatchesDevice(rv1126b, 0x2207, 0x110f) &&
            !rockchipLoaderMatchesDevice(rv1126b, 0x2207, 0x110c) &&
            !rockchipLoaderMatchesDevice(rv1106, 0x2207, 0x110f) &&
            !rockchipLoaderMatchesDevice(rv1106.left(24), 0x2207, 0x110c) &&
            !rockchipLoaderMatchesDevice(QByteArray(102, '\0'), 0x2207, 0x110c) &&
            !rockchipLoaderMatchesDevice(rv1106, 0x1234, 0x110c) &&
            loadDefaultBootloader(0x2207, 0x110c).isEmpty() &&
            loadDefaultBootloader(0x2207, 0x110b).isEmpty();
    if (!passed)
        qCritical() << "Rockchip device/loader compatibility regression";
    return passed ? 0 : 1;
}
