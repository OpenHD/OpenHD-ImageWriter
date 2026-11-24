#include "file_operations.h"

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <winioctl.h>

#include <QDebug>
#include <algorithm>
#include <atomic>
#include <limits>

namespace {

FileError errorFromWindows(DWORD error)
{
    switch (error)
    {
    case ERROR_FILE_NOT_FOUND:
    case ERROR_PATH_NOT_FOUND:
        return FileError::NotFound;
    case ERROR_NOT_READY:
    case ERROR_NO_MEDIA_IN_DRIVE:
        return FileError::NotReady;
    case ERROR_ACCESS_DENIED:
    case ERROR_PRIVILEGE_NOT_HELD:
    case ERROR_WRITE_PROTECT:
        return FileError::AccessDenied;
    case ERROR_SHARING_VIOLATION:
    case ERROR_LOCK_VIOLATION:
        return FileError::Busy;
    case ERROR_OPERATION_ABORTED:
        return FileError::Cancelled;
    case ERROR_INVALID_PARAMETER:
        return FileError::InvalidArgument;
    default:
        return FileError::IoError;
    }
}

class WindowsFileOperations final : public FileOperations
{
public:
    ~WindowsFileOperations() override { close(); }

    FileError openDevice(const QString &path, bool exclusive) override
    {
        close();
        resetCancellation();
        _lastErrorDetail.clear();
        const bool physicalDrive = path.startsWith(QStringLiteral("\\\\.\\PHYSICALDRIVE"),
                                                   Qt::CaseInsensitive);
        _physicalDrive = physicalDrive;
        _writeChunkLimit = std::numeric_limits<DWORD>::max();
        _haveMediaChangeCount = false;
        // Windows storage services and security scanners commonly retain handles
        // that request read/write sharing even after every mounted volume has been
        // locked and dismounted.  Permit both share modes for the physical disk;
        // WindowsDiskPreparation has already locked, dismounted, and cleared the
        // selected disk before this handle is opened.
        const DWORD sharing = exclusive ? (physicalDrive ? FILE_SHARE_READ | FILE_SHARE_WRITE : 0)
                                        : FILE_SHARE_READ | FILE_SHARE_WRITE;
        const int attempts = physicalDrive ? 20 : 1;
        FileError result = FileError::IoError;
        for (int attempt = 0; attempt < attempts; ++attempt)
        {
            _handle = CreateFileW(reinterpret_cast<LPCWSTR>(path.utf16()),
                                  GENERIC_READ | GENERIC_WRITE, sharing, nullptr,
                                  OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
            if (_handle != INVALID_HANDLE_VALUE)
            {
                if (physicalDrive || path.startsWith(QStringLiteral("\\\\.\\"), Qt::CaseInsensitive))
                {
                    DWORD returned = 0;
                    DeviceIoControl(_handle, FSCTL_ALLOW_EXTENDED_DASD_IO, nullptr, 0,
                                    nullptr, 0, &returned, nullptr);
                }
                if (physicalDrive)
                    _haveMediaChangeCount = readMediaChangeCount(_mediaChangeCount);
                return FileError::Success;
            }
            result = recordError(GetLastError());
            if ((result != FileError::Busy && result != FileError::NotReady) ||
                attempt + 1 == attempts) break;
            Sleep(100);
        }
        return result;
    }

    FileError adoptNativeHandle(qintptr handle, bool takeOwnership, bool) override
    {
        close();
        resetCancellation();
        _physicalDrive = false;
        _writeChunkLimit = std::numeric_limits<DWORD>::max();
        _haveMediaChangeCount = false;
        const HANDLE source = reinterpret_cast<HANDLE>(handle);
        if (!source || source == INVALID_HANDLE_VALUE) return FileError::InvalidArgument;
        if (takeOwnership)
        {
            _handle = source;
        }
        else
        {
            if (!DuplicateHandle(GetCurrentProcess(), source, GetCurrentProcess(), &_handle,
                                   0, FALSE, DUPLICATE_SAME_ACCESS))
                return recordError(GetLastError());
        }
        DWORD returned = 0;
        DeviceIoControl(_handle, FSCTL_ALLOW_EXTENDED_DASD_IO, nullptr, 0,
                        nullptr, 0, &returned, nullptr);
        return FileError::Success;
    }

    FileError close() override
    {
        if (_handle == INVALID_HANDLE_VALUE)
            return FileError::Success;
        const HANDLE handle = _handle;
        _handle = INVALID_HANDLE_VALUE;
        return CloseHandle(handle) ? FileError::Success : recordError(GetLastError());
    }

    bool isOpen() const override { return _handle != INVALID_HANDLE_VALUE; }
    qintptr nativeHandle() const override { return reinterpret_cast<qintptr>(_handle); }

    FileError writeSequential(const quint8 *data, std::size_t size,
                              std::size_t &bytesWritten) override
    {
        bytesWritten = 0;
        _lastErrorDetail.clear();
        if (!isOpen()) return FileError::NotOpen;
        if (!data && size) return FileError::InvalidArgument;

        constexpr DWORD compatibilityChunkSize = 128 * 1024;
        int retries = 0;
        while (bytesWritten < size)
        {
            if (_cancelled.load()) return FileError::Cancelled;
            const DWORD chunk = static_cast<DWORD>(std::min<std::size_t>(
                size - bytesWritten, _writeChunkLimit));
            LARGE_INTEGER offset = {};
            const bool haveOffset = _physicalDrive &&
                SetFilePointerEx(_handle, offset, &offset, FILE_CURRENT);
            DWORD written = 0;
            if (!WriteFile(_handle, data + bytesWritten, chunk, &written, nullptr))
            {
                const DWORD code = GetLastError();
                const FileError error = recordError(code);
                _lastErrorDetail += QStringLiteral(" (WriteFile at byte %1, %2-byte write)")
                    .arg(haveOffset ? static_cast<quint64>(offset.QuadPart) : position()).arg(chunk);
                qWarning().noquote() << _lastErrorDetail;
                if (!haveOffset || _cancelled.load() || retries == 5 ||
                    (code != ERROR_NOT_READY &&
                     !(error == FileError::InvalidArgument && chunk > compatibilityChunkSize)))
                    return error;
                // Retry the same bytes on the locked disk at the original offset.
                // Some readers accept smaller transfers after rejecting a full batch.
                if (code == ERROR_NOT_READY)
                {
                    if (!_haveMediaChangeCount)
                    {
                        _lastErrorDetail += QStringLiteral("; reader did not report the initial media change count");
                        return error;
                    }
                    for (;;)
                    {
                        Sleep(100U << retries++);
                        if (_cancelled.load()) return FileError::Cancelled;
                        ULONG mediaChangeCount = 0;
                        if (readMediaChangeCount(mediaChangeCount))
                        {
                            if (mediaChangeCount != _mediaChangeCount)
                            {
                                _lastErrorDetail += QStringLiteral("; media change detected");
                                return error;
                            }
                            break;
                        }
                        if (retries == 5)
                        {
                            _lastErrorDetail += QStringLiteral("; media did not become ready during recovery");
                            return error;
                        }
                    }
                }
                else
                {
                    ++retries;
                }
                _writeChunkLimit = compatibilityChunkSize;
                const FileError rewind = seek(static_cast<quint64>(offset.QuadPart));
                if (rewind != FileError::Success) return rewind;
                continue;
            }
            if (written == 0) return FileError::IoError;
            bytesWritten += written;
            retries = 0;
        }
        return FileError::Success;
    }

    FileError readSequential(quint8 *data, std::size_t size,
                             std::size_t &bytesRead) override
    {
        bytesRead = 0;
        if (!isOpen()) return FileError::NotOpen;
        if (!data && size) return FileError::InvalidArgument;
        if (_cancelled.load()) return FileError::Cancelled;

        const DWORD chunk = static_cast<DWORD>(std::min<std::size_t>(
            size, std::numeric_limits<DWORD>::max()));
        DWORD read = 0;
        if (!ReadFile(_handle, data, chunk, &read, nullptr))
            return recordError(GetLastError());
        bytesRead = read;
        return FileError::Success;
    }

    FileError seek(quint64 position) override
    {
        if (!isOpen()) return FileError::NotOpen;
        _lastErrorDetail.clear();
        LARGE_INTEGER target;
        target.QuadPart = static_cast<LONGLONG>(position);
        if (SetFilePointerEx(_handle, target, nullptr, FILE_BEGIN))
            return FileError::Success;
        const DWORD code = GetLastError();
        const FileError error = recordError(code);
        _lastErrorDetail += QStringLiteral(" (SetFilePointerEx at byte %1)").arg(position);
        return error;
    }

    quint64 position() const override
    {
        if (!isOpen()) return 0;
        LARGE_INTEGER zero = {};
        LARGE_INTEGER current = {};
        return SetFilePointerEx(_handle, zero, &current, FILE_CURRENT)
                   ? static_cast<quint64>(current.QuadPart) : 0;
    }

    FileError size(quint64 &bytes) const override
    {
        bytes = 0;
        if (!isOpen()) return FileError::NotOpen;
        GET_LENGTH_INFORMATION deviceLength = {};
        DWORD returned = 0;
        if (DeviceIoControl(_handle, IOCTL_DISK_GET_LENGTH_INFO, nullptr, 0,
                            &deviceLength, sizeof(deviceLength), &returned, nullptr))
        {
            bytes = static_cast<quint64>(deviceLength.Length.QuadPart);
            return FileError::Success;
        }
        LARGE_INTEGER length;
        if (!GetFileSizeEx(_handle, &length)) return recordError(GetLastError());
        bytes = static_cast<quint64>(length.QuadPart);
        return FileError::Success;
    }

    FileError flush() override
    {
        if (!isOpen()) return FileError::NotOpen;
        if (_cancelled.load()) return FileError::Cancelled;
        _lastErrorDetail.clear();
        if (FlushFileBuffers(_handle)) return FileError::Success;
        const DWORD code = GetLastError();
        const FileError error = recordError(code);
        _lastErrorDetail += QStringLiteral(" (FlushFileBuffers at byte %1)").arg(position());
        return error;
    }

    QString lastErrorDetail() const override { return _lastErrorDetail; }

    void cancel() override
    {
        _cancelled.store(true);
        if (isOpen()) CancelIoEx(_handle, nullptr);
    }

    void resetCancellation() override { _cancelled.store(false); }

private:
    bool readMediaChangeCount(ULONG &count) const
    {
        DWORD returned = 0;
        return DeviceIoControl(_handle, IOCTL_STORAGE_CHECK_VERIFY, nullptr, 0,
                               &count, sizeof(count), &returned, nullptr) &&
               returned == sizeof(count);
    }

    FileError recordError(DWORD code) const
    {
        wchar_t *buffer = nullptr;
        const DWORD length = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER |
            FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, nullptr,
            code, 0, reinterpret_cast<wchar_t *>(&buffer), 0, nullptr);
        _lastErrorDetail = QStringLiteral("Windows error %1: %2").arg(code).arg(
            length && buffer ? QString::fromWCharArray(buffer, int(length)).trimmed() : QString());
        if (buffer) LocalFree(buffer);
        qWarning().noquote() << _lastErrorDetail;
        return errorFromWindows(code);
    }
    mutable QString _lastErrorDetail;
    HANDLE _handle = INVALID_HANDLE_VALUE;
    bool _physicalDrive = false;
    bool _haveMediaChangeCount = false;
    ULONG _mediaChangeCount = 0;
    DWORD _writeChunkLimit = std::numeric_limits<DWORD>::max();
    std::atomic<bool> _cancelled{false};
};

} // namespace

std::unique_ptr<FileOperations> FileOperations::create()
{
    return std::unique_ptr<FileOperations>(new WindowsFileOperations());
}
