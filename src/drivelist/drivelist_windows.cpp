/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include "drivelist.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <cfgmgr32.h>
#include <setupapi.h>
#include <shlobj.h>
#include <winioctl.h>

#include <algorithm>
#include <cwctype>
#include <set>
#include <vector>

namespace Drivelist {
namespace {

const GUID DiskInterfaceGuid = {
    0x53F56307L, 0xB6BF, 0x11D0,
    {0x94, 0xF2, 0x00, 0xA0, 0xC9, 0x1E, 0xFB, 0x8B}
};

class Handle final
{
public:
    explicit Handle(HANDLE value = INVALID_HANDLE_VALUE) : _value(value) {}
    ~Handle() { if (valid()) CloseHandle(_value); }
    Handle(const Handle &) = delete;
    Handle &operator=(const Handle &) = delete;
    bool valid() const { return _value != INVALID_HANDLE_VALUE && _value != nullptr; }
    HANDLE get() const { return _value; }
private:
    HANDLE _value;
};

class DeviceInfoSet final
{
public:
    explicit DeviceInfoSet(HDEVINFO value) : _value(value) {}
    ~DeviceInfoSet() { if (valid()) SetupDiDestroyDeviceInfoList(_value); }
    bool valid() const { return _value != INVALID_HANDLE_VALUE; }
    HDEVINFO get() const { return _value; }
private:
    HDEVINFO _value;
};

std::string utf8(const std::wstring &value)
{
    if (value.empty()) return {};
    const int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                            value.data(), static_cast<int>(value.size()),
                                            nullptr, 0, nullptr, nullptr);
    if (length <= 0) return {};
    std::string result(static_cast<size_t>(length), '\0');
    if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                             static_cast<int>(value.size()), &result[0], length,
                             nullptr, nullptr))
        return {};
    return result;
}

std::wstring property(HDEVINFO info, SP_DEVINFO_DATA &device, DWORD key)
{
    DWORD type = 0;
    DWORD required = 0;
    SetupDiGetDeviceRegistryPropertyW(info, &device, key, &type, nullptr, 0, &required);
    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER || required < sizeof(wchar_t))
        return {};
    std::vector<BYTE> bytes(required + sizeof(wchar_t), 0);
    if (!SetupDiGetDeviceRegistryPropertyW(info, &device, key, &type,
                                            bytes.data(), required, nullptr))
        return {};
    return std::wstring(reinterpret_cast<const wchar_t *>(bytes.data()));
}

std::wstring upper(std::wstring value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](wchar_t character) {
        return static_cast<wchar_t>(std::towupper(character));
    });
    return value;
}

bool containsAny(const std::wstring &value, const std::vector<std::wstring> &needles)
{
    const std::wstring normalized = upper(value);
    for (const std::wstring &needle : needles)
        if (normalized.find(upper(needle)) != std::wstring::npos) return true;
    return false;
}

int diskNumber(HANDLE handle)
{
    STORAGE_DEVICE_NUMBER number = {};
    DWORD returned = 0;
    if (!DeviceIoControl(handle, IOCTL_STORAGE_GET_DEVICE_NUMBER, nullptr, 0,
                         &number, sizeof(number), &returned, nullptr))
        return -1;
    return number.DeviceType == FILE_DEVICE_DISK
               ? static_cast<int>(number.DeviceNumber) : -1;
}

std::string busTypeName(int type)
{
    switch (type)
    {
    case BusTypeUsb: return "USB";
    case BusTypeScsi: return "SCSI";
    case BusTypeAta: return "ATA";
    case BusTypeSata: return "SATA";
    case BusTypeSd: return "SD";
    case BusTypeMmc: return "MMC";
    case BusTypeSas: return "SAS";
    case BusTypeRAID: return "RAID";
    case BusTypeVirtual: return "VIRTUAL";
    case BusTypeFileBackedVirtual: return "FILEBACKEDVIRTUAL";
    // BusTypeNvme was added after the Windows 7 SDK used by the legacy Qt 5
    // build, but the numeric value is stable in newer SDKs.
    case 17: return "NVME";
    default: return "UNKNOWN";
    }
}

void readGeometry(HANDLE handle, DeviceDescriptor &device)
{
    GET_LENGTH_INFORMATION length = {};
    DWORD returned = 0;
    if (DeviceIoControl(handle, IOCTL_DISK_GET_LENGTH_INFO, nullptr, 0,
                        &length, sizeof(length), &returned, nullptr))
        device.size = static_cast<uint64_t>(length.Length.QuadPart);
    else
    {
        DISK_GEOMETRY_EX geometry = {};
        if (DeviceIoControl(handle, IOCTL_DISK_GET_DRIVE_GEOMETRY_EX, nullptr, 0,
                            &geometry, sizeof(geometry), &returned, nullptr))
        {
            device.size = static_cast<uint64_t>(geometry.DiskSize.QuadPart);
            device.blockSize = geometry.Geometry.BytesPerSector;
        }
    }

    STORAGE_PROPERTY_QUERY query = {};
    query.PropertyId = StorageAccessAlignmentProperty;
    query.QueryType = PropertyStandardQuery;
    STORAGE_ACCESS_ALIGNMENT_DESCRIPTOR alignment = {};
    if (DeviceIoControl(handle, IOCTL_STORAGE_QUERY_PROPERTY, &query, sizeof(query),
                        &alignment, sizeof(alignment), &returned, nullptr))
    {
        if (alignment.BytesPerPhysicalSector) device.blockSize = alignment.BytesPerPhysicalSector;
        if (alignment.BytesPerLogicalSector) device.logicalBlockSize = alignment.BytesPerLogicalSector;
    }

    query.PropertyId = StorageAdapterProperty;
    STORAGE_ADAPTER_DESCRIPTOR adapter = {};
    if (DeviceIoControl(handle, IOCTL_STORAGE_QUERY_PROPERTY, &query, sizeof(query),
                        &adapter, sizeof(adapter), &returned, nullptr))
    {
        device.busType = busTypeName(adapter.BusType);
        device.busVersion = std::to_string(adapter.BusMajorVersion) + "." +
                            std::to_string(adapter.BusMinorVersion);
        device.busVersionNull = false;
    }
    device.isReadOnly = !DeviceIoControl(handle, IOCTL_DISK_IS_WRITABLE,
                                          nullptr, 0, nullptr, 0, &returned, nullptr);
}

std::vector<std::string> mountpointsForDisk(int targetDisk)
{
    std::vector<std::string> result;
    const DWORD required = GetLogicalDriveStringsW(0, nullptr);
    if (!required) return result;
    std::vector<wchar_t> roots(required + 1, L'\0');
    if (!GetLogicalDriveStringsW(required, roots.data())) return result;

    for (const wchar_t *root = roots.data(); *root; root += wcslen(root) + 1)
    {
        const UINT type = GetDriveTypeW(root);
        if (type != DRIVE_FIXED && type != DRIVE_REMOVABLE) continue;
        std::wstring volumePath = L"\\\\.\\";
        volumePath.append(root, root + 2);
        Handle volume(CreateFileW(volumePath.c_str(), 0, FILE_SHARE_READ | FILE_SHARE_WRITE,
                                  nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
        if (!volume.valid()) continue;
        // A volume can span several disks. Reserve enough room to inspect all
        // ordinary layouts instead of silently ignoring anything beyond the
        // single inline extent in VOLUME_DISK_EXTENTS.
        std::vector<BYTE> extentBytes(sizeof(VOLUME_DISK_EXTENTS) +
                                      63 * sizeof(DISK_EXTENT), 0);
        auto *extents = reinterpret_cast<VOLUME_DISK_EXTENTS *>(extentBytes.data());
        DWORD returned = 0;
        if (DeviceIoControl(volume.get(), IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,
                            nullptr, 0, extents, static_cast<DWORD>(extentBytes.size()),
                            &returned, nullptr))
        {
            for (DWORD extent = 0; extent < extents->NumberOfDiskExtents; ++extent)
            {
                if (static_cast<int>(extents->Extents[extent].DiskNumber) == targetDisk)
                {
                    result.push_back(utf8(root));
                    break;
                }
            }
        }
    }
    return result;
}

bool isSystemMount(const std::vector<std::string> &mountpoints)
{
    const KNOWNFOLDERID folders[] = {FOLDERID_Windows, FOLDERID_Profile,
                                      FOLDERID_ProgramData, FOLDERID_ProgramFiles,
                                      FOLDERID_ProgramFilesX86};
    for (const KNOWNFOLDERID &folder : folders)
    {
        PWSTR path = nullptr;
        if (SUCCEEDED(SHGetKnownFolderPath(folder, 0, nullptr, &path)) && path)
        {
            const std::wstring knownPath = upper(path);
            CoTaskMemFree(path);
            for (const std::string &mountpoint : mountpoints)
            {
                const std::wstring wideMount(mountpoint.begin(), mountpoint.end());
                if (knownPath.find(upper(wideMount)) == 0) return true;
            }
        }
        else if (path)
            CoTaskMemFree(path);
    }
    return false;
}

bool removalPolicy(HDEVINFO info, SP_DEVINFO_DATA &device)
{
    DWORD policy = 0, type = 0;
    if (!SetupDiGetDeviceRegistryPropertyW(info, &device, SPDRP_REMOVAL_POLICY,
                                            &type, reinterpret_cast<BYTE *>(&policy),
                                            sizeof(policy), nullptr))
        return false;
    return policy == CM_REMOVAL_POLICY_EXPECT_ORDERLY_REMOVAL ||
           policy == CM_REMOVAL_POLICY_EXPECT_SURPRISE_REMOVAL;
}

} // namespace

std::vector<DeviceDescriptor> ListStorageDevices()
{
    std::vector<DeviceDescriptor> devices;
    DeviceInfoSet info(SetupDiGetClassDevsW(&DiskInterfaceGuid, nullptr, nullptr,
                                             DIGCF_PRESENT | DIGCF_DEVICEINTERFACE));
    if (!info.valid())
    {
        DeviceDescriptor error;
        error.device = "__error__";
        error.error = "SetupDiGetClassDevs failed: " + std::to_string(GetLastError());
        devices.push_back(error);
        return devices;
    }

    std::set<int> seenDiskNumbers;
    for (DWORD index = 0;; ++index)
    {
        SP_DEVICE_INTERFACE_DATA interfaceData = {};
        interfaceData.cbSize = sizeof(interfaceData);
        if (!SetupDiEnumDeviceInterfaces(info.get(), nullptr, &DiskInterfaceGuid,
                                          index, &interfaceData))
        {
            if (GetLastError() != ERROR_NO_MORE_ITEMS)
            {
                DeviceDescriptor error;
                error.device = "__error__";
                error.error = "SetupDiEnumDeviceInterfaces failed: " +
                              std::to_string(GetLastError());
                devices.insert(devices.begin(), error);
            }
            break;
        }

        DWORD required = 0;
        SetupDiGetDeviceInterfaceDetailW(info.get(), &interfaceData, nullptr, 0,
                                          &required, nullptr);
        if (GetLastError() != ERROR_INSUFFICIENT_BUFFER || !required) continue;
        std::vector<BYTE> detailBytes(required, 0);
        auto *detail = reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W *>(detailBytes.data());
        detail->cbSize = sizeof(*detail);
        SP_DEVINFO_DATA deviceInfo = {};
        deviceInfo.cbSize = sizeof(deviceInfo);
        if (!SetupDiGetDeviceInterfaceDetailW(info.get(), &interfaceData, detail,
                                               required, nullptr, &deviceInfo))
            continue;

        Handle interfaceHandle(CreateFileW(detail->DevicePath, 0,
                                            FILE_SHARE_READ | FILE_SHARE_WRITE,
                                            nullptr, OPEN_EXISTING,
                                            FILE_ATTRIBUTE_NORMAL, nullptr));
        if (!interfaceHandle.valid()) continue;
        const int number = diskNumber(interfaceHandle.get());
        if (number < 0 || !seenDiskNumbers.insert(number).second) continue;

        DeviceDescriptor device;
        device.device = device.raw = "\\\\.\\PHYSICALDRIVE" + std::to_string(number);
        device.devicePath = utf8(detail->DevicePath);
        device.devicePathNull = device.devicePath.empty();
        device.enumerator = utf8(property(info.get(), deviceInfo, SPDRP_ENUMERATOR_NAME));
        device.description = utf8(property(info.get(), deviceInfo, SPDRP_FRIENDLYNAME));
        if (device.description.empty())
            device.description = utf8(property(info.get(), deviceInfo, SPDRP_DEVICEDESC));
        device.isRemovable = removalPolicy(info.get(), deviceInfo);

        const std::wstring hardwareId = property(info.get(), deviceInfo, SPDRP_HARDWAREID);
        device.isVirtual = containsAny(hardwareId, {L"VIRTUAL", L"VHD", L"QEMU",
                                                    L"VBOX", L"VMWARE"});

        const std::wstring physicalPath(device.device.begin(), device.device.end());
        Handle physical(CreateFileW(physicalPath.c_str(), 0,
                                     FILE_SHARE_READ | FILE_SHARE_WRITE,
                                     nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
        if (!physical.valid()) continue;
        readGeometry(physical.get(), device);
        device.mountpoints = mountpointsForDisk(number);
        device.isSystem = isSystemMount(device.mountpoints);

        const std::string enumeratorUpper = utf8(upper(std::wstring(
            device.enumerator.begin(), device.enumerator.end())));
        device.isUSB = device.busType == "USB" || enumeratorUpper == "USBSTOR" ||
                       enumeratorUpper == "UASPSTOR" || enumeratorUpper == "VUSBSTOR";
        device.isUAS = enumeratorUpper == "UASPSTOR" ||
                       (device.busType == "USB" && enumeratorUpper == "SCSI");
        device.isUASNull = false;
        device.isCard = device.busType == "SD" || device.busType == "MMC";
        device.isSCSI = !device.isUSB &&
                        (device.busType == "SCSI" || device.busType == "SAS");
        device.isVirtual = device.isVirtual || device.busType == "VIRTUAL" ||
                           device.busType == "FILEBACKEDVIRTUAL";
        devices.push_back(device);
    }
    return devices;
}

} // namespace Drivelist
