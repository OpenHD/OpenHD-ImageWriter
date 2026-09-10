#ifndef DRIVESAFETYPOLICY_H
#define DRIVESAFETYPOLICY_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QString>
#include <QStringList>
#include <QtGlobal>

struct DriveCandidate
{
    QString device;
    QString description;
    QString busType;
    QString enumerator;
    QStringList mountpoints;
    quint64 size = 0;
    bool readOnly = false;
    bool system = false;
    bool virtualDevice = false;
    bool removable = false;
    bool usb = false;
    bool uas = false;
    bool scsi = false;
};

struct SafeDrive
{
    QString key;
    QString description;
    bool displayable = false;
    bool system = false;
    bool usb = false;
    bool scsi = false;
};

class DriveSafetyPolicy final
{
public:
    static SafeDrive evaluate(const DriveCandidate &candidate);
    static QString sanitizeDescription(const QString &description);
    static bool hasSystemMountpoint(const QStringList &mountpoints);
};

#endif // DRIVESAFETYPOLICY_H
