/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include "drivelist.h"

#import <Cocoa/Cocoa.h>
#import <DiskArbitration/DiskArbitration.h>
#import <IOKit/IOBSD.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/storage/IOMedia.h>

namespace Drivelist {
namespace {

bool isPartition(NSString *name)
{
    NSPredicate *wholeDisk = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                                                         @"disk\\d+"];
    return ![wholeDisk evaluateWithObject:name];
}

NSNumber *numberProperty(CFDictionaryRef description, const void *key)
{
    return (NSNumber *)CFDictionaryGetValue(description, key);
}

NSString *stringProperty(CFDictionaryRef description, const void *key)
{
    return (NSString *)CFDictionaryGetValue(description, key);
}

bool isCard(CFDictionaryRef description)
{
    CFDictionaryRef icon = (CFDictionaryRef)CFDictionaryGetValue(
        description, kDADiskDescriptionMediaIconKey);
    if (!icon) return false;
    CFStringRef key = CFSTR("IOBundleResourceFile");
    CFStringRef name = (CFStringRef)CFDictionaryGetValue(icon, key);
    return name && [(NSString *)name isEqualToString:@"SD.icns"];
}

std::string findApfsParent(const char *bsdName)
{
    io_service_t current = IOServiceGetMatchingService(
        kIOMasterPortDefault, IOBSDNameMatching(kIOMasterPortDefault, 0, bsdName));
    if (!current) return {};

    for (int level = 0; level < 3; ++level)
    {
        io_service_t parent = IO_OBJECT_NULL;
        if (IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) != KERN_SUCCESS)
        {
            IOObjectRelease(current);
            return {};
        }
        IOObjectRelease(current);
        current = parent;
    }

    std::string result;
    io_iterator_t parents = IO_OBJECT_NULL;
    if (IORegistryEntryGetParentIterator(current, kIOServicePlane, &parents) == KERN_SUCCESS)
    {
        io_service_t parent = IO_OBJECT_NULL;
        while ((parent = IOIteratorNext(parents)))
        {
            if (IOObjectConformsTo(parent, kIOMediaClass))
            {
                CFTypeRef property = IORegistryEntryCreateCFProperty(
                    parent, CFSTR(kIOBSDNameKey), kCFAllocatorDefault, 0);
                if (property && CFGetTypeID(property) == CFStringGetTypeID())
                    result = [(NSString *)property UTF8String];
                if (property) CFRelease(property);
            }
            IOObjectRelease(parent);
            if (!result.empty()) break;
        }
        IOObjectRelease(parents);
    }
    IOObjectRelease(current);
    return result;
}

DeviceDescriptor descriptorForDisk(const std::string &bsdName, CFDictionaryRef properties)
{
    DeviceDescriptor device;
    NSString *protocol = stringProperty(properties, kDADiskDescriptionDeviceProtocolKey);
    NSNumber *blockSize = numberProperty(properties, kDADiskDescriptionMediaBlockSizeKey);
    const bool internal = [numberProperty(properties, kDADiskDescriptionDeviceInternalKey) boolValue];
    const bool removable = [numberProperty(properties, kDADiskDescriptionMediaRemovableKey) boolValue];
    const bool ejectable = [numberProperty(properties, kDADiskDescriptionMediaEjectableKey) boolValue];

    device.enumerator = "DiskArbitration";
    device.device = "/dev/" + bsdName;
    device.raw = "/dev/r" + bsdName;
    NSString *mediaName = stringProperty(properties, kDADiskDescriptionMediaNameKey);
    device.description = mediaName ? [mediaName UTF8String] : bsdName;
    NSString *busPath = stringProperty(properties, kDADiskDescriptionBusPathKey);
    if (busPath)
    {
        device.devicePath = [busPath UTF8String];
        device.devicePathNull = false;
    }
    device.size = [numberProperty(properties, kDADiskDescriptionMediaSizeKey) unsignedLongLongValue];
    device.blockSize = blockSize ? [blockSize unsignedIntValue] : 512;
    device.logicalBlockSize = device.blockSize;
    device.busType = protocol ? [protocol UTF8String] : "";
    device.isUSB = protocol && [protocol isEqualToString:@"USB"];
    device.isCard = isCard(properties);
    device.isVirtual = protocol && [protocol isEqualToString:@"Virtual Interface"];
    NSArray *scsiProtocols = @[@"SATA", @"SCSI", @"ATA", @"IDE", @"PCI", @"NVMe"];
    device.isSCSI = !device.isUSB && protocol && [scsiProtocols containsObject:protocol];
    device.isReadOnly = ![numberProperty(properties, kDADiskDescriptionMediaWritableKey) boolValue];
    device.isRemovable = removable || ejectable;
    device.isSystem = internal && !device.isRemovable && !device.isCard;

    if (device.description == "AppleAPFSMedia")
    {
        device.isVirtual = true;
        device.parentDevice = findApfsParent(bsdName.c_str());
    }
    return device;
}

void diskAppeared(DADiskRef disk, void *context)
{
    const char *name = DADiskGetBSDName(disk);
    if (name)
        [(NSMutableArray *)context addObject:[NSString stringWithUTF8String:name]];
}

bool enumerateDiskNames(NSMutableArray *names)
{
    DASessionRef session = DASessionCreate(kCFAllocatorDefault);
    if (!session) return false;
    DARegisterDiskAppearedCallback(session, nullptr, diskAppeared, names);
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    DASessionScheduleWithRunLoop(session, runLoop, kCFRunLoopDefaultMode);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
    DAUnregisterCallback(session, reinterpret_cast<void *>(diskAppeared), names);
    DASessionUnscheduleFromRunLoop(session, runLoop, kCFRunLoopDefaultMode);
    CFRelease(session);
    [names sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return true;
}

void addMountpoints(std::vector<DeviceDescriptor> &devices, DASessionRef session)
{
    NSArray *keys = @[NSURLVolumeNameKey, NSURLVolumeLocalizedNameKey];
    NSArray *volumes = [[NSFileManager defaultManager]
        mountedVolumeURLsIncludingResourceValuesForKeys:keys options:0];
    for (NSURL *volume in volumes)
    {
        DADiskRef disk = DADiskCreateFromVolumePath(
            kCFAllocatorDefault, session, (CFURLRef)volume);
        if (!disk) continue;
        const char *name = DADiskGetBSDName(disk);
        if (!name)
        {
            CFRelease(disk);
            continue;
        }

        NSString *volumeName = nil;
        [volume getResourceValue:&volumeName forKey:NSURLVolumeLocalizedNameKey error:nil];
        std::string partition(name);
        const size_t separator = partition.find('s', 5);
        std::string wholeDisk = separator == std::string::npos
                                    ? partition : partition.substr(0, separator);
        std::string apfsChild;
        for (const DeviceDescriptor &device : devices)
        {
            if (device.device == "/dev/" + wholeDisk && !device.parentDevice.empty())
            {
                apfsChild = wholeDisk;
                wholeDisk = device.parentDevice;
                break;
            }
        }
        for (DeviceDescriptor &device : devices)
        {
            if (device.device != "/dev/" + wholeDisk) continue;
            device.mountpoints.push_back([[volume path] UTF8String]);
            device.mountpointLabels.push_back(volumeName ? [volumeName UTF8String] : "");
            if (!apfsChild.empty()) device.childDevices.push_back("/dev/" + apfsChild);
            break;
        }
        CFRelease(disk);
    }
}

DeviceDescriptor errorDescriptor(const char *message)
{
    DeviceDescriptor error;
    error.device = "__error__";
    error.description = "Drive enumeration failed";
    error.error = message;
    return error;
}

} // namespace

std::vector<DeviceDescriptor> ListStorageDevices()
{
    std::vector<DeviceDescriptor> devices;
    @autoreleasepool
    {
        DASessionRef session = DASessionCreate(kCFAllocatorDefault);
        if (!session) return {errorDescriptor("DiskArbitration session creation failed")};

        NSMutableArray *names = [NSMutableArray array];
        if (!enumerateDiskNames(names))
        {
            CFRelease(session);
            return {errorDescriptor("DiskArbitration enumeration failed")};
        }
        devices.reserve([names count]);
        for (NSString *name in names)
        {
            if (isPartition(name)) continue;
            const std::string bsdName = [name UTF8String];
            DADiskRef disk = DADiskCreateFromBSDName(
                kCFAllocatorDefault, session, bsdName.c_str());
            if (!disk) continue;
            CFDictionaryRef properties = DADiskCopyDescription(disk);
            if (properties)
            {
                devices.push_back(descriptorForDisk(bsdName, properties));
                CFRelease(properties);
            }
            CFRelease(disk);
        }
        addMountpoints(devices, session);
        CFRelease(session);
    }
    return devices;
}

} // namespace Drivelist
