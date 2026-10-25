/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "rockchipdevice.h"

#ifdef Q_OS_WIN
#include <initguid.h>
#include <usbiodef.h>
#endif

#include <QCoreApplication>
#include <QDebug>
#include <QTextStream>
#include <QtEndian>

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

    const bool passed =
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
