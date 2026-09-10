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
#include <QThread>

#include <algorithm>
#include <vector>

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

bool LockedVolumes::lockAndDismount(const std::vector<std::string> &mountpoints,
                                     QString *error)
{
    release();
    for (const std::string &mountpoint : mountpoints)
    {
        const QString path = volumePath(mountpoint);
        if (path.isEmpty()) continue;
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
    bool success = DeviceIoControl(handle, IOCTL_DISK_DELETE_DRIVE_LAYOUT,
                                   nullptr, 0, nullptr, 0, &returned, nullptr);
    DWORD code = success ? ERROR_SUCCESS : GetLastError();
    if (!success && (code == ERROR_INVALID_FUNCTION || code == ERROR_FILE_NOT_FOUND ||
                     code == ERROR_NOT_FOUND))
        success = true;

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
    CloseHandle(handle);
    if (!success && error)
        *error = windowsError(QStringLiteral("Could not clear the target partition table"), code);
    return success;
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

    if (error) *error = QStringLiteral("Windows did not expose a mountable FAT volume");
    return {};
}

} // namespace WindowsDiskPreparation
