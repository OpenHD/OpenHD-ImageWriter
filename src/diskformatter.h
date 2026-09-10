#ifndef DISKFORMATTER_H
#define DISKFORMATTER_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include <QByteArray>
#include <QString>

enum class DiskFormatError
{
    Success,
    OpenFailed,
    InvalidSize,
    SeekFailed,
    WriteFailed,
    FlushFailed
};

class DiskFormatter final
{
public:
    DiskFormatError formatFat32(const QString &devicePath,
                                const QByteArray &volumeLabel = QByteArray("SDCARD"));
    static QString errorMessage(DiskFormatError error);
};

#endif // DISKFORMATTER_H
