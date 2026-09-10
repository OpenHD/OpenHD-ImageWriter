#include "file_operations.h"

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include <cerrno>
#include <atomic>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <linux/fs.h>

#include <QFile>

namespace {

FileError errorFromErrno(int error)
{
    switch (error)
    {
    case ENOENT: return FileError::NotFound;
    case EACCES:
    case EPERM: return FileError::AccessDenied;
    case EBUSY:
    case EAGAIN: return FileError::Busy;
    case EINVAL: return FileError::InvalidArgument;
    case ECANCELED: return FileError::Cancelled;
    default: return FileError::IoError;
    }
}

class LinuxFileOperations final : public FileOperations
{
public:
    ~LinuxFileOperations() override { close(); }

    FileError openDevice(const QString &path, bool exclusive) override
    {
        close();
        resetCancellation();
        const QByteArray encodedPath = QFile::encodeName(path);
        int flags = O_RDWR | O_CLOEXEC;
        if (exclusive && path.startsWith(QStringLiteral("/dev/")))
            flags |= O_EXCL;
        _fd = ::open(encodedPath.constData(), flags);
        if (_fd < 0) return errorFromErrno(errno);
        if (exclusive && ::flock(_fd, LOCK_EX | LOCK_NB) != 0)
        {
            const FileError error = errorFromErrno(errno);
            close();
            return error;
        }
        return FileError::Success;
    }

    FileError adoptNativeHandle(qintptr handle, bool takeOwnership, bool exclusive) override
    {
        close();
        resetCancellation();
        const int source = static_cast<int>(handle);
        if (source < 0) return FileError::InvalidArgument;
        _fd = takeOwnership ? source : ::dup(source);
        if (_fd < 0) return errorFromErrno(errno);
        if (exclusive && ::flock(_fd, LOCK_EX | LOCK_NB) != 0)
        {
            const FileError error = errorFromErrno(errno);
            close();
            return error;
        }
        return FileError::Success;
    }

    FileError close() override
    {
        if (_fd < 0) return FileError::Success;
        const int fd = _fd;
        _fd = -1;
        return ::close(fd) == 0 ? FileError::Success : errorFromErrno(errno);
    }

    bool isOpen() const override { return _fd >= 0; }
    qintptr nativeHandle() const override { return static_cast<qintptr>(_fd); }

    FileError writeSequential(const quint8 *data, std::size_t size,
                              std::size_t &bytesWritten) override
    {
        bytesWritten = 0;
        if (!isOpen()) return FileError::NotOpen;
        if (!data && size) return FileError::InvalidArgument;
        while (bytesWritten < size)
        {
            if (_cancelled.load()) return FileError::Cancelled;
            const ssize_t written = ::write(_fd, data + bytesWritten, size - bytesWritten);
            if (written < 0)
            {
                if (errno == EINTR) continue;
                return errorFromErrno(errno);
            }
            if (written == 0) return FileError::IoError;
            bytesWritten += static_cast<std::size_t>(written);
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
        ssize_t result;
        do { result = ::read(_fd, data, size); } while (result < 0 && errno == EINTR);
        if (result < 0) return errorFromErrno(errno);
        bytesRead = static_cast<std::size_t>(result);
        return FileError::Success;
    }

    FileError seek(quint64 position) override
    {
        if (!isOpen()) return FileError::NotOpen;
        return ::lseek(_fd, static_cast<off_t>(position), SEEK_SET) >= 0
                   ? FileError::Success : errorFromErrno(errno);
    }

    quint64 position() const override
    {
        if (!isOpen()) return 0;
        const off_t result = ::lseek(_fd, 0, SEEK_CUR);
        return result >= 0 ? static_cast<quint64>(result) : 0;
    }

    FileError size(quint64 &bytes) const override;

    FileError flush() override
    {
        if (!isOpen()) return FileError::NotOpen;
        if (_cancelled.load()) return FileError::Cancelled;
        return ::fsync(_fd) == 0 ? FileError::Success : errorFromErrno(errno);
    }

    void cancel() override { _cancelled.store(true); }
    void resetCancellation() override { _cancelled.store(false); }

private:
    int _fd = -1;
    std::atomic<bool> _cancelled{false};
};

FileError LinuxFileOperations::size(quint64 &bytes) const
{
    bytes = 0;
    if (!isOpen()) return FileError::NotOpen;
    unsigned long long blockBytes = 0;
    if (::ioctl(_fd, BLKGETSIZE64, &blockBytes) == 0)
    {
        bytes = static_cast<quint64>(blockBytes);
        return FileError::Success;
    }
    struct stat status;
    if (::fstat(_fd, &status) != 0) return errorFromErrno(errno);
    bytes = static_cast<quint64>(status.st_size);
    return FileError::Success;
}

} // namespace

std::unique_ptr<FileOperations> FileOperations::create()
{
    return std::unique_ptr<FileOperations>(new LinuxFileOperations());
}
