/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "drivesafetypolicy.h"

#include <QDir>
#include <QSet>

QString DriveSafetyPolicy::sanitizeDescription(const QString &description)
{
    QString result;
    result.reserve(description.size());
    for (const QChar character : description)
    {
        const QChar::Category category = character.category();
        if (category == QChar::Other_Format || category == QChar::Other_Control ||
            category == QChar::Other_Surrogate || category == QChar::Other_NotAssigned)
            continue;
        result.append(character);
    }
    return result.simplified().left(256);
}

bool DriveSafetyPolicy::hasSystemMountpoint(const QStringList &mountpoints)
{
    static const QSet<QString> unixSystemMounts = {
        QStringLiteral("/"), QStringLiteral("/boot"), QStringLiteral("/boot/efi"),
        QStringLiteral("/home"), QStringLiteral("/usr"), QStringLiteral("/var")
    };
    for (QString mountpoint : mountpoints)
    {
        mountpoint = QDir::cleanPath(mountpoint.trimmed());
        if (unixSystemMounts.contains(mountpoint) || mountpoint.startsWith(QStringLiteral("/snap/")))
            return true;
#ifdef Q_OS_WIN
        QString systemRoot = qEnvironmentVariable("SystemDrive", "C:");
        systemRoot = QDir::cleanPath(systemRoot + QLatin1Char('/'));
        if (mountpoint.compare(systemRoot, Qt::CaseInsensitive) == 0)
            return true;
#else
        if (mountpoint.compare(QStringLiteral("C:/"), Qt::CaseInsensitive) == 0 ||
            mountpoint.compare(QStringLiteral("C:\\"), Qt::CaseInsensitive) == 0)
            return true;
#endif
    }
    return false;
}

SafeDrive DriveSafetyPolicy::evaluate(const DriveCandidate &candidate)
{
    SafeDrive result;
    QString device = candidate.device.trimmed();
    device.replace('/', QDir::separator());
#ifdef Q_OS_WIN
    device = device.toLower();
#endif
    result.key = device + QLatin1Char(':') + QString::number(candidate.size);
    if (candidate.readOnly)
        result.key += QStringLiteral(":ro");

    result.description = sanitizeDescription(candidate.description);
    if (result.description.isEmpty())
        result.description = candidate.device;
    result.system = candidate.system || hasSystemMountpoint(candidate.mountpoints);

    const QString bus = candidate.busType.trimmed().toUpper();
    const QString enumerator = candidate.enumerator.trimmed().toUpper();
    result.usb = candidate.usb || candidate.uas || bus == QStringLiteral("USB") ||
                 enumerator == QStringLiteral("USBSTOR") ||
                 enumerator == QStringLiteral("UASPSTOR") ||
                 enumerator == QStringLiteral("VUSBSTOR");
    result.scsi = candidate.scsi && !result.usb;

    result.displayable = !device.isEmpty() && candidate.size > 0;
    if (candidate.virtualDevice &&
        (candidate.readOnly || result.system || !candidate.removable))
        result.displayable = false;
    return result;
}
