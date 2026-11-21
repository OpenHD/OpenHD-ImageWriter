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

class FileOperations;

class DiskFormatter final
{
public:
    DiskFormatError formatFat32(const QString &devicePath,
                                const QByteArray &volumeLabel = QByteArray("SDCARD"));
    static QString errorMessage(DiskFormatError error);
    // Full-flash only. Recognizes OPENHD/RECORDINGS FAT volumes; never scans
    // host disks or formats a boot/config partition. Publishes changes in the
    // buffered first block only after recording filesystem verification.
    static bool prepareOpenHDStorage(char *firstBlock, std::size_t firstBlockSize,
                                     FileOperations &file, quint64 imageSize,
                                     quint64 targetSize, QString *error);
    static bool relocateGptBackup(char *firstBlock, std::size_t firstBlockSize,
                                  FileOperations &file, quint64 targetSize);
};

#endif // DISKFORMATTER_H
