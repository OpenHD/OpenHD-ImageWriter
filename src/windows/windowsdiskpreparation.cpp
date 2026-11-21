/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "windowsdiskpreparation.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <shlobj.h>
#include <winioctl.h>

#include <QElapsedTimer>
#include <QStringList>
#include <QThread>

#include <algorithm>
#include <vector>

#ifndef IOCTL_DISK_SET_DISK_ATTRIBUTES
#define IOCTL_DISK_SET_DISK_ATTRIBUTES \
    CTL_CODE(IOCTL_DISK_BASE, 0x003d, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)
#define DISK_ATTRIBUTE_OFFLINE 0x0000000000000001ULL
#define DISK_ATTRIBUTE_READ_ONLY 0x0000000000000002ULL
typedef struct _OPENHD_SET_DISK_ATTRIBUTES {
    DWORD Version;
    BOOLEAN Persist;
    BYTE Reserved1[3];
    DWORDLONG Attributes;
    DWORDLONG AttributesMask;
    DWORD Reserved2[4];
} OPENHD_SET_DISK_ATTRIBUTES;
#else
typedef SET_DISK_ATTRIBUTES OPENHD_SET_DISK_ATTRIBUTES;
#endif

namespace WindowsDiskPreparation {
namespace {

QString windowsError(const QString &operation, DWORD code)
{
    wchar_t *buffer = nullptr;
    const DWORD length = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
            FORMAT_MESSAGE_IGNORE_INSERTS,
        nullptr, code, 0, reinterpret_cast<wchar_t *>(&buffer), 0, nullptr);
    const QString detail = length && buffer
                               ? QString::fromWCharArray(buffer, static_cast<int>(length)).trimmed()
                               : QStringLiteral("Windows error %1").arg(code);
    if (buffer) LocalFree(buffer);
    return QStringLiteral("%1: %2").arg(operation, detail);
}

QString volumePath(const std::string &mountpoint)
{
    QString path = QString::fromStdString(mountpoint).trimmed();
    while (path.endsWith(QLatin1Char('\\')) || path.endsWith(QLatin1Char('/')))
        path.chop(1);
    if (path.size() != 2 || path.at(1) != QLatin1Char(':')) return {};
    return QStringLiteral("\\\\.\\") + path;
}

int physicalDiskNumber(const QString &path)
{
    const QString prefix = QStringLiteral("\\\\.\\PHYSICALDRIVE");
    if (!path.startsWith(prefix, Qt::CaseInsensitive)) return -1;
    bool valid = false;
    const int number = path.mid(prefix.size()).toInt(&valid);
    return valid && number >= 0 ? number : -1;
}

bool volumeUsesDisk(const wchar_t *volumeName, int diskNumber)
{
    std::wstring openPath(volumeName);
    if (!openPath.empty() && openPath.back() == L'\\') openPath.pop_back();
    HANDLE volume = CreateFileW(openPath.c_str(), 0,
                                FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (volume == INVALID_HANDLE_VALUE) return false;
    std::vector<BYTE> bytes(sizeof(VOLUME_DISK_EXTENTS) + 63 * sizeof(DISK_EXTENT), 0);
    auto *extents = reinterpret_cast<VOLUME_DISK_EXTENTS *>(bytes.data());
    DWORD returned = 0;
    const bool queried = DeviceIoControl(volume, IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,
                                         nullptr, 0, extents,
                                         static_cast<DWORD>(bytes.size()), &returned, nullptr);
    CloseHandle(volume);
    if (!queried) return false;
    for (DWORD extent = 0; extent < extents->NumberOfDiskExtents; ++extent)
        if (static_cast<int>(extents->Extents[extent].DiskNumber) == diskNumber)
            return true;
    return false;
}

QString mountedDriveRoot(const wchar_t *volumeName)
{
    DWORD required = 0;
    GetVolumePathNamesForVolumeNameW(volumeName, nullptr, 0, &required);
    if (!required) return {};
    std::vector<wchar_t> paths(required + 1, L'\0');
    if (!GetVolumePathNamesForVolumeNameW(volumeName, paths.data(), required, &required))
        return {};
    for (const wchar_t *path = paths.data(); *path; path += wcslen(path) + 1)
        if (wcslen(path) == 3 && path[1] == L':' && path[2] == L'\\')
            return QString::fromWCharArray(path);
    return {};
}

bool isFatVolume(const wchar_t *volumeName)
{
    wchar_t filesystem[MAX_PATH] = {};
    if (!GetVolumeInformationW(volumeName, nullptr, 0, nullptr, nullptr, nullptr,
                               filesystem, MAX_PATH))
        return false;
    return _wcsicmp(filesystem, L"FAT") == 0 || _wcsicmp(filesystem, L"FAT32") == 0;
}

bool clearDiskAccessRestrictions(HANDLE handle, QString *error)
{
    OPENHD_SET_DISK_ATTRIBUTES attributes = {};
    attributes.Version = sizeof(attributes);
    attributes.Attributes = 0;
    attributes.AttributesMask = DISK_ATTRIBUTE_OFFLINE | DISK_ATTRIBUTE_READ_ONLY;
    for (const BOOLEAN persist : {TRUE, FALSE})
    {
        attributes.Persist = persist;
        DWORD returned = 0;
        if (DeviceIoControl(handle, IOCTL_DISK_SET_DISK_ATTRIBUTES,
                            &attributes, sizeof(attributes), nullptr, 0, &returned, nullptr))
            continue;
        const DWORD code = GetLastError();
        if (code == ERROR_INVALID_FUNCTION || code == ERROR_NOT_SUPPORTED ||
            code == ERROR_INVALID_PARAMETER)
            continue; // Some USB bridges do not implement disk attributes.
        if (error)
            *error = windowsError(QStringLiteral("Could not clear disk offline/read-only attributes"), code);
        return false;
    }
    return true;
}

QString firstAvailableDriveRoot()
{
    const DWORD used = GetLogicalDrives();
    for (wchar_t letter = L'D'; letter <= L'Z'; ++letter)
        if (!(used & (1UL << (letter - L'A'))))
            return QString(QChar(letter)) + QStringLiteral(":\\");
    return {};
}

} // namespace

LockedVolumes::~LockedVolumes()
{
    release();
}

bool LockedVolumes::lockAndDismount(const QString &physicalDrive,
                                     const std::vector<std::string> &mountpoints,
                                     QString *error)
{
    release();
    const int diskNumber = physicalDiskNumber(physicalDrive);
    if (diskNumber < 0)
    {
        if (error) *error = QStringLiteral("Invalid Windows physical-drive path");
        return false;
    }

    QStringList paths;
    wchar_t volumeName[MAX_PATH] = {};
    HANDLE search = FindFirstVolumeW(volumeName, MAX_PATH);
    if (search != INVALID_HANDLE_VALUE)
    {
        do {
            if (volumeUsesDisk(volumeName, diskNumber))
            {
                QString path = QString::fromWCharArray(volumeName);
                path.chop(1); // Open the volume itself, without the trailing slash.
                paths.append(path);
            }
        } while (FindNextVolumeW(search, volumeName, MAX_PATH));
        const DWORD code = GetLastError();
        FindVolumeClose(search);
        if (code != ERROR_NO_MORE_FILES)
        {
            if (error) *error = windowsError(QStringLiteral("Could not enumerate disk volumes"), code);
            return false;
        }
    }
    else if (GetLastError() != ERROR_NO_MORE_FILES)
    {
        if (error) *error = windowsError(QStringLiteral("Could not enumerate disk volumes"), GetLastError());
        return false;
    }

    // Some removable readers expose a drive letter before their volume GUID.
    for (const std::string &mountpoint : mountpoints)
    {
        QString path = volumePath(mountpoint);
        if (path.isEmpty()) continue;
        const QString root = path.mid(4) + QLatin1Char('\\');
        if (GetVolumeNameForVolumeMountPointW(reinterpret_cast<LPCWSTR>(root.utf16()),
                                              volumeName, MAX_PATH))
        {
            path = QString::fromWCharArray(volumeName);
            path.chop(1);
        }
        if (!paths.contains(path, Qt::CaseInsensitive))
            paths.append(path);
    }

    for (const QString &path : paths)
    {
        HANDLE handle = CreateFileW(reinterpret_cast<LPCWSTR>(path.utf16()),
                                    GENERIC_READ | GENERIC_WRITE,
                                    FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                                    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (handle == INVALID_HANDLE_VALUE)
        {
            if (error) *error = windowsError(QStringLiteral("Could not open %1").arg(path),
                                             GetLastError());
            release();
            return false;
        }

        DWORD returned = 0;
        bool locked = false;
        DWORD lastError = ERROR_LOCK_VIOLATION;
        for (int attempt = 0, delayMs = 100; attempt < 6; ++attempt, delayMs *= 2)
        {
            if (DeviceIoControl(handle, FSCTL_LOCK_VOLUME, nullptr, 0, nullptr, 0,
                                &returned, nullptr))
            {
                locked = true;
                break;
            }
            lastError = GetLastError();
            if (attempt != 5) Sleep(static_cast<DWORD>(delayMs));
        }
        if (!locked)
        {
            if (error) *error = windowsError(QStringLiteral("Could not lock %1").arg(path),
                                             lastError);
            CloseHandle(handle);
            release();
            return false;
        }
        if (!DeviceIoControl(handle, FSCTL_DISMOUNT_VOLUME, nullptr, 0, nullptr, 0,
                             &returned, nullptr))
        {
            const DWORD code = GetLastError();
            DeviceIoControl(handle, FSCTL_UNLOCK_VOLUME, nullptr, 0, nullptr, 0,
                            &returned, nullptr);
            CloseHandle(handle);
            if (error) *error = windowsError(QStringLiteral("Could not dismount %1").arg(path),
                                             code);
            release();
            return false;
        }
        _handles.push_back(handle);
    }
    return true;
}

void LockedVolumes::release()
{
    for (void *value : _handles)
    {
        HANDLE handle = static_cast<HANDLE>(value);
        DWORD returned = 0;
        DeviceIoControl(handle, FSCTL_UNLOCK_VOLUME, nullptr, 0, nullptr, 0,
                        &returned, nullptr);
        CloseHandle(handle);
    }
    _handles.clear();
}

bool clearPartitionTable(const QString &physicalDrive, QString *error)
{
    HANDLE handle = CreateFileW(reinterpret_cast<LPCWSTR>(physicalDrive.utf16()),
                                GENERIC_READ | GENERIC_WRITE,
                                FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (handle == INVALID_HANDLE_VALUE)
    {
        if (error) *error = windowsError(QStringLiteral("Could not open target disk"),
                                         GetLastError());
        return false;
    }
    DWORD returned = 0;
    DeviceIoControl(handle, FSCTL_ALLOW_EXTENDED_DASD_IO, nullptr, 0, nullptr, 0,
                    &returned, nullptr);
    if (!clearDiskAccessRestrictions(handle, error))
    {
        CloseHandle(handle);
        return false;
    }
    bool success = DeviceIoControl(handle, IOCTL_DISK_DELETE_DRIVE_LAYOUT,
                                   nullptr, 0, nullptr, 0, &returned, nullptr);
    DWORD code = success ? ERROR_SUCCESS : GetLastError();
    if (!success)
    {
        DISK_GEOMETRY geometry = {};
        const bool haveGeometry = DeviceIoControl(handle, IOCTL_DISK_GET_DRIVE_GEOMETRY,
                                                   nullptr, 0, &geometry, sizeof(geometry),
                                                   &returned, nullptr);
        const DWORD sectorSize = haveGeometry && geometry.BytesPerSector
                                     ? geometry.BytesPerSector : 512;
        std::vector<unsigned char> zeroes(std::max<DWORD>(sectorSize, 512), 0);
        LARGE_INTEGER start = {};
        DWORD written = 0;
        success = SetFilePointerEx(handle, start, nullptr, FILE_BEGIN) &&
                  WriteFile(handle, zeroes.data(), static_cast<DWORD>(zeroes.size()),
                            &written, nullptr) && written == zeroes.size() &&
                  FlushFileBuffers(handle);
        if (!success) code = GetLastError();
    }
    if (success)
        DeviceIoControl(handle, IOCTL_DISK_UPDATE_PROPERTIES,
                        nullptr, 0, nullptr, 0, &returned, nullptr);
    CloseHandle(handle);
    if (!success && error)
        *error = windowsError(QStringLiteral("Could not clear the target partition table"), code);
    return success;
}

bool probeWritableTail(const QString &physicalDrive, QString *error)
{
    HANDLE handle = CreateFileW(reinterpret_cast<LPCWSTR>(physicalDrive.utf16()),
                                GENERIC_READ | GENERIC_WRITE,
                                FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (handle == INVALID_HANDLE_VALUE)
    {
        if (error) *error = windowsError(QStringLiteral("Could not open target for write preflight"),
                                         GetLastError());
        return false;
    }
    DWORD returned = 0;
    DeviceIoControl(handle, FSCTL_ALLOW_EXTENDED_DASD_IO, nullptr, 0,
                    nullptr, 0, &returned, nullptr);
    if (!clearDiskAccessRestrictions(handle, error))
    {
        CloseHandle(handle);
        return false;
    }
    GET_LENGTH_INFORMATION length = {};
    if (!DeviceIoControl(handle, IOCTL_DISK_GET_LENGTH_INFO, nullptr, 0,
                         &length, sizeof(length), &returned, nullptr))
    {
        const DWORD code = GetLastError();
        CloseHandle(handle);
        if (error) *error = windowsError(QStringLiteral("Could not determine target size for write preflight"), code);
        return false;
    }
    if (length.Length.QuadPart < 2 * 1024 * 1024)
    {
        CloseHandle(handle);
        if (error) *error = QStringLiteral("Target is too small for a safe write preflight");
        return false;
    }

    constexpr DWORD probeSize = 1024 * 1024;
    const LONGLONG offset = length.Length.QuadPart - probeSize;
    std::vector<BYTE> original(probeSize), probe(probeSize), readback(probeSize);
    for (DWORD i = 0; i < probeSize; ++i)
        probe[i] = static_cast<BYTE>((i * 37U + 0x5aU) & 0xffU);

    LARGE_INTEGER position = {};
    position.QuadPart = offset;
    DWORD count = 0;
    QString failedStep;
    DWORD code = ERROR_SUCCESS;
    bool success = SetFilePointerEx(handle, position, nullptr, FILE_BEGIN) != FALSE;
    if (!success)
    {
        failedStep = QStringLiteral("seek to target tail");
        code = GetLastError();
    }
    if (success)
    {
        success = ReadFile(handle, original.data(), probeSize, &count, nullptr) != FALSE;
        if (!success || count != probeSize)
        {
            failedStep = QStringLiteral("read original target tail");
            code = success ? ERROR_READ_FAULT : GetLastError();
            success = false;
        }
    }
    bool restoreNeeded = false;
    if (success)
    {
        position.QuadPart = offset;
        const bool positioned = SetFilePointerEx(handle, position, nullptr, FILE_BEGIN) != FALSE;
        if (!positioned)
        {
            success = false;
            failedStep = QStringLiteral("seek before tail write test");
            code = GetLastError();
        }
        const bool wrote = success && WriteFile(handle, probe.data(), probeSize, &count, nullptr);
        restoreNeeded = count > 0;
        if (success && (!wrote || count != probeSize))
        {
            success = false;
            failedStep = QStringLiteral("write test data to target tail");
            code = wrote ? ERROR_WRITE_FAULT : GetLastError();
        }
        if (success)
        {
            restoreNeeded = true;
            success = FlushFileBuffers(handle) != FALSE;
            if (!success)
            {
                failedStep = QStringLiteral("flush target tail write test");
                code = GetLastError();
            }
        }
    }
    if (success)
    {
        position.QuadPart = offset;
        const bool positioned = SetFilePointerEx(handle, position, nullptr, FILE_BEGIN) != FALSE;
        const bool read = positioned && ReadFile(handle, readback.data(), probeSize, &count, nullptr);
        success = read && count == probeSize && readback == probe;
        if (!success)
        {
            failedStep = QStringLiteral("read back target tail write test");
            code = !positioned || !read ? GetLastError()
                                        : (count != probeSize ? ERROR_READ_FAULT : ERROR_CRC);
        }
    }

    // Restore the original bytes before reporting either success or failure.
    bool restored = true;
    DWORD restoreCode = ERROR_SUCCESS;
    if (restoreNeeded)
    {
        position.QuadPart = offset;
        DWORD restoreCount = 0;
        const bool positioned = SetFilePointerEx(handle, position, nullptr, FILE_BEGIN) != FALSE;
        const bool wrote = positioned && WriteFile(handle, original.data(), probeSize,
                                                    &restoreCount, nullptr);
        restored = wrote && restoreCount == probeSize && FlushFileBuffers(handle);
        if (!restored)
            restoreCode = GetLastError() ? GetLastError() : ERROR_WRITE_FAULT;
    }
    if (restored)
    {
        std::fill(readback.begin(), readback.end(), 0);
        position.QuadPart = offset;
        const bool restoreVerified = SetFilePointerEx(handle, position, nullptr, FILE_BEGIN) &&
                                     ReadFile(handle, readback.data(), probeSize, &count, nullptr) &&
                                     count == probeSize && readback == original;
        if (!restoreVerified)
        {
            success = false;
            restoreCode = readback == original ? (GetLastError() ? GetLastError() : ERROR_READ_FAULT)
                                               : ERROR_CRC;
            restored = false;
        }
    }
    CloseHandle(handle);

    if (!restored)
    {
        if (error)
            *error = QStringLiteral("Tail preflight failed during %1 (%2); restoring original bytes also failed (%3)")
                         .arg(failedStep, windowsError(QStringLiteral("write/readback"), code),
                              windowsError(QStringLiteral("restore"), restoreCode));
        return false;
    }
    if (!success)
    {
        if (error) *error = windowsError(QStringLiteral("Target tail preflight failed during %1; original bytes were restored")
                                              .arg(failedStep), code);
        return false;
    }
    return true;
}

bool rescanDisk(const QString &physicalDrive, QString *error)
{
    HANDLE handle = CreateFileW(reinterpret_cast<LPCWSTR>(physicalDrive.utf16()),
                                GENERIC_READ | GENERIC_WRITE,
                                FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (handle == INVALID_HANDLE_VALUE)
    {
        if (error) *error = windowsError(QStringLiteral("Could not open target for rescan"),
                                         GetLastError());
        return false;
    }
    DWORD returned = 0;
    DeviceIoControl(handle, FSCTL_ALLOW_EXTENDED_DASD_IO, nullptr, 0, nullptr, 0,
                    &returned, nullptr);

    // USB-booted Compute Modules and removable drives can be left offline or
    // read-only by Windows after partition table changes. Both persistent
    // (registry) and volatile flags must be cleared so partmgr will not
    // re-impose offline/read-only on reload.
    OPENHD_SET_DISK_ATTRIBUTES attributes = {};
    attributes.Version = sizeof(attributes);
    attributes.Persist = TRUE;
    attributes.Attributes = 0;
    attributes.AttributesMask = DISK_ATTRIBUTE_OFFLINE | DISK_ATTRIBUTE_READ_ONLY;
    DeviceIoControl(handle, IOCTL_DISK_SET_DISK_ATTRIBUTES,
                    &attributes, sizeof(attributes), nullptr, 0, &returned, nullptr);

    attributes.Persist = FALSE;
    DeviceIoControl(handle, IOCTL_DISK_SET_DISK_ATTRIBUTES,
                    &attributes, sizeof(attributes), nullptr, 0, &returned, nullptr);

    const bool success = DeviceIoControl(handle, IOCTL_DISK_UPDATE_PROPERTIES,
                                         nullptr, 0, nullptr, 0, &returned, nullptr);
    const DWORD code = success ? ERROR_SUCCESS : GetLastError();
    CloseHandle(handle);
    if (!success)
    {
        if (error) *error = windowsError(QStringLiteral("Could not refresh target partitions"), code);
        return false;
    }
    SHChangeNotify(SHCNE_DRIVEADD, SHCNF_IDLIST, nullptr, nullptr);
    return true;
}

QString ensureDriveLetter(const QString &physicalDrive, int timeoutMs, QString *error)
{
    const int diskNumber = physicalDiskNumber(physicalDrive);
    if (diskNumber < 0)
    {
        if (error) *error = QStringLiteral("Invalid Windows physical-drive path");
        return {};
    }

    QElapsedTimer timer;
    timer.start();
    do
    {
        // Some USB mass-storage gadgets enumerate their partitions several
        // seconds after the raw disk write has completed.
        QString ignoredError;
        (void)rescanDisk(physicalDrive, &ignoredError);
        std::wstring fallbackVolume;
        wchar_t volumeName[MAX_PATH] = {};
        HANDLE search = FindFirstVolumeW(volumeName, MAX_PATH);
        if (search != INVALID_HANDLE_VALUE)
        {
            do
            {
                if (!volumeUsesDisk(volumeName, diskNumber)) continue;
                const QString mounted = mountedDriveRoot(volumeName);
                if (!mounted.isEmpty() && isFatVolume(volumeName))
                {
                    FindVolumeClose(search);
                    return mounted;
                }
                if (isFatVolume(volumeName) || fallbackVolume.empty())
                    fallbackVolume = volumeName;
            }
            while (FindNextVolumeW(search, volumeName, MAX_PATH));
            FindVolumeClose(search);
        }

        if (!fallbackVolume.empty())
        {
            const QString existing = mountedDriveRoot(fallbackVolume.c_str());
            if (!existing.isEmpty()) return existing;
            const QString root = firstAvailableDriveRoot();
            if (!root.isEmpty() && SetVolumeMountPointW(
                    reinterpret_cast<LPCWSTR>(root.utf16()), fallbackVolume.c_str()))
            {
                SHChangeNotify(SHCNE_DRIVEADD, SHCNF_PATHW,
                               reinterpret_cast<LPCWSTR>(root.utf16()), nullptr);
                return root;
            }
        }
        if (timer.elapsed() < timeoutMs) QThread::msleep(200);
    }
    while (timer.elapsed() < timeoutMs);

    if (error) *error = QStringLiteral("Windows did not expose a mountable FAT volume after refreshing the device");
    return {};
}

} // namespace WindowsDiskPreparation
