#ifndef FILE_OPERATIONS_H
#define FILE_OPERATIONS_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include <QtGlobal>
#include <QString>

#include <cstddef>
#include <memory>

enum class FileError
{
    Success,
    NotOpen,
    NotFound,
    AccessDenied,
    Busy,
    InvalidArgument,
    Cancelled,
    IoError
};

QString fileErrorMessage(FileError error);

class FileOperations
{
public:
    virtual ~FileOperations() = default;

    static std::unique_ptr<FileOperations> create();

    virtual FileError openDevice(const QString &path, bool exclusive = true) = 0;
    virtual FileError adoptNativeHandle(qintptr handle, bool takeOwnership = true,
                                        bool exclusive = true) = 0;
    virtual FileError close() = 0;
    virtual bool isOpen() const = 0;
    virtual qintptr nativeHandle() const = 0;

    virtual FileError writeSequential(const quint8 *data, std::size_t size,
                                      std::size_t &bytesWritten) = 0;
    virtual FileError readSequential(quint8 *data, std::size_t size,
                                     std::size_t &bytesRead) = 0;
    virtual FileError seek(quint64 position) = 0;
    virtual quint64 position() const = 0;
    virtual FileError size(quint64 &bytes) const = 0;
    virtual FileError flush() = 0;

    virtual void cancel() = 0;
    virtual void resetCancellation() = 0;
};

#endif // FILE_OPERATIONS_H
