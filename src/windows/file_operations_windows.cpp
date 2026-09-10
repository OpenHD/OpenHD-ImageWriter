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
    case ERROR_ACCESS_DENIED:
    case ERROR_PRIVILEGE_NOT_HELD:
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
        const bool physicalDrive = path.startsWith(QStringLiteral("\\\\.\\PHYSICALDRIVE"),
                                                   Qt::CaseInsensitive);
        // Physical disks are shared for reads so Windows storage services can keep
        // their existing handles, while FILE_SHARE_WRITE still remains denied.
        const DWORD sharing = exclusive ? (physicalDrive ? FILE_SHARE_READ : 0)
                                        : FILE_SHARE_READ | FILE_SHARE_WRITE;
        const int attempts = physicalDrive ? 20 : 1;
        FileError result = FileError::IoError;
        for (int attempt = 0; attempt < attempts; ++attempt)
        {
            _handle = CreateFileW(reinterpret_cast<LPCWSTR>(path.utf16()),
                                  GENERIC_READ | GENERIC_WRITE, sharing, nullptr,
                                  OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
            if (_handle != INVALID_HANDLE_VALUE) return FileError::Success;
            result = errorFromWindows(GetLastError());
            if (result != FileError::Busy || attempt + 1 == attempts) break;
            Sleep(100);
        }
        return result;
    }

    FileError adoptNativeHandle(qintptr handle, bool takeOwnership, bool) override
    {
        close();
        resetCancellation();
        const HANDLE source = reinterpret_cast<HANDLE>(handle);
        if (!source || source == INVALID_HANDLE_VALUE) return FileError::InvalidArgument;
        if (takeOwnership)
        {
            _handle = source;
            return FileError::Success;
        }
        return DuplicateHandle(GetCurrentProcess(), source, GetCurrentProcess(), &_handle,
                               0, FALSE, DUPLICATE_SAME_ACCESS)
                   ? FileError::Success : errorFromWindows(GetLastError());
    }

    FileError close() override
    {
        if (_handle == INVALID_HANDLE_VALUE)
            return FileError::Success;
        const HANDLE handle = _handle;
        _handle = INVALID_HANDLE_VALUE;
        return CloseHandle(handle) ? FileError::Success : errorFromWindows(GetLastError());
    }

    bool isOpen() const override { return _handle != INVALID_HANDLE_VALUE; }
    qintptr nativeHandle() const override { return reinterpret_cast<qintptr>(_handle); }

    FileError writeSequential(const quint8 *data, std::size_t size,
                              std::size_t &bytesWritten) override
    {
        bytesWritten = 0;
        if (!isOpen()) return FileError::NotOpen;
        if (!data && size) return FileError::InvalidArgument;

        while (bytesWritten < size)
        {
            if (_cancelled.load()) return FileError::Cancelled;
            const DWORD chunk = static_cast<DWORD>(std::min<std::size_t>(
                size - bytesWritten, std::numeric_limits<DWORD>::max()));
            DWORD written = 0;
            if (!WriteFile(_handle, data + bytesWritten, chunk, &written, nullptr))
                return errorFromWindows(GetLastError());
            if (written == 0) return FileError::IoError;
            bytesWritten += written;
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
            return errorFromWindows(GetLastError());
        bytesRead = read;
        return FileError::Success;
    }

    FileError seek(quint64 position) override
    {
        if (!isOpen()) return FileError::NotOpen;
        LARGE_INTEGER target;
        target.QuadPart = static_cast<LONGLONG>(position);
        return SetFilePointerEx(_handle, target, nullptr, FILE_BEGIN)
                   ? FileError::Success : errorFromWindows(GetLastError());
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
        if (!GetFileSizeEx(_handle, &length)) return errorFromWindows(GetLastError());
        bytes = static_cast<quint64>(length.QuadPart);
        return FileError::Success;
    }

    FileError flush() override
    {
        if (!isOpen()) return FileError::NotOpen;
        if (_cancelled.load()) return FileError::Cancelled;
        return FlushFileBuffers(_handle) ? FileError::Success
                                         : errorFromWindows(GetLastError());
    }

    void cancel() override
    {
        _cancelled.store(true);
        if (isOpen()) CancelIoEx(_handle, nullptr);
    }

    void resetCancellation() override { _cancelled.store(false); }

private:
    HANDLE _handle = INVALID_HANDLE_VALUE;
    std::atomic<bool> _cancelled{false};
};

} // namespace

std::unique_ptr<FileOperations> FileOperations::create()
{
    return std::unique_ptr<FileOperations>(new WindowsFileOperations());
}
