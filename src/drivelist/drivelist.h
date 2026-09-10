#ifndef OPENHD_DRIVELIST_H
#define OPENHD_DRIVELIST_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include <cstdint>
#include <string>
#include <vector>

namespace Drivelist {

struct DeviceDescriptor
{
    std::string enumerator;
    std::string busType;
    std::string busVersion;
    bool busVersionNull = true;
    std::string device;
    std::string devicePath;
    bool devicePathNull = true;
    std::string parentDevice;
    std::string raw;
    std::string description;
    std::string error;
    uint64_t size = 0;
    uint32_t blockSize = 512;
    uint32_t logicalBlockSize = 512;
    std::vector<std::string> mountpoints;
    std::vector<std::string> mountpointLabels;
    std::vector<std::string> childDevices;
    bool isReadOnly = false;
    bool isSystem = false;
    bool isVirtual = false;
    bool isRemovable = false;
    bool isCard = false;
    bool isSCSI = false;
    bool isUSB = false;
    bool isUAS = false;
    bool isUASNull = true;
};

std::vector<DeviceDescriptor> ListStorageDevices();

} // namespace Drivelist

#endif // OPENHD_DRIVELIST_H
