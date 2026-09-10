/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include "drivelist.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QProcess>
#include <QStandardPaths>
#include <QStringList>

#include <algorithm>

namespace Drivelist {
namespace {

bool booleanValue(const QJsonValue &value)
{
    if (value.isBool()) return value.toBool();
    if (value.isDouble()) return value.toInt() != 0;
    const QString text = value.toString().trimmed().toLower();
    return text == QStringLiteral("1") || text == QStringLiteral("true") ||
           text == QStringLiteral("yes");
}

uint64_t unsignedValue(const QJsonValue &value, uint64_t fallback = 0)
{
    if (value.isDouble()) return static_cast<uint64_t>(value.toDouble());
    bool valid = false;
    const qulonglong result = value.toString().toULongLong(&valid);
    return valid ? static_cast<uint64_t>(result) : fallback;
}

void appendMountpoint(DeviceDescriptor &device, const QString &path, const QString &label)
{
    const QString cleanPath = path.trimmed();
    if (cleanPath.isEmpty()) return;
    const std::string mountpoint = cleanPath.toStdString();
    if (std::find(device.mountpoints.begin(), device.mountpoints.end(), mountpoint) !=
        device.mountpoints.end())
        return;
    device.mountpoints.push_back(mountpoint);
    device.mountpointLabels.push_back(label.trimmed().toStdString());
}

void collectNode(DeviceDescriptor &device, const QJsonObject &node, QStringList &labels)
{
    const QString label = node.value(QStringLiteral("label")).toString().trimmed();
    if (!label.isEmpty() && !labels.contains(label)) labels.append(label);

    const QJsonValue mountpoints = node.value(QStringLiteral("mountpoints"));
    if (mountpoints.isArray())
    {
        for (const QJsonValue &mountpoint : mountpoints.toArray())
            appendMountpoint(device, mountpoint.toString(), label);
    }
    else
        appendMountpoint(device, node.value(QStringLiteral("mountpoint")).toString(), label);

    const QString childPath = node.value(QStringLiteral("path")).toString();
    if (!childPath.isEmpty() && childPath.toStdString() != device.device)
        device.childDevices.push_back(childPath.toStdString());

    for (const QJsonValue &child : node.value(QStringLiteral("children")).toArray())
        collectNode(device, child.toObject(), labels);
}

bool protectedMountpoint(const std::string &mountpoint)
{
    const QString path = QString::fromStdString(mountpoint);
    return path == QStringLiteral("/") || path == QStringLiteral("/boot") ||
           path == QStringLiteral("/boot/efi") || path == QStringLiteral("/home") ||
           path == QStringLiteral("/usr") || path == QStringLiteral("/var") ||
           path.startsWith(QStringLiteral("/snap/"));
}

QByteArray runLsblk(QString &error)
{
    const QString executable = QStandardPaths::findExecutable(QStringLiteral("lsblk"));
    if (executable.isEmpty())
    {
        error = QStringLiteral("lsblk was not found");
        return {};
    }

    const QString commonColumns = QStringLiteral(
        "NAME,KNAME,PATH,SIZE,TYPE,RO,RM,HOTPLUG,MOUNTPOINT,LABEL,VENDOR,MODEL,TRAN,"
        "SUBSYSTEMS,LOG-SEC,PHY-SEC");
    const QStringList columnSets = {
        commonColumns + QStringLiteral(",MOUNTPOINTS"), commonColumns
    };
    for (const QString &columns : columnSets)
    {
        QProcess process;
        process.setProcessChannelMode(QProcess::SeparateChannels);
        process.start(executable, {QStringLiteral("--bytes"), QStringLiteral("--json"),
                                   QStringLiteral("--paths"), QStringLiteral("--output"),
                                   columns});
        if (!process.waitForStarted(2000))
        {
            error = process.errorString();
            return {};
        }
        if (!process.waitForFinished(5000))
        {
            process.kill();
            process.waitForFinished(1000);
            error = QStringLiteral("lsblk timed out");
            return {};
        }
        const QByteArray output = process.readAllStandardOutput();
        if (process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0 &&
            !output.isEmpty())
            return output;
        error = QString::fromLocal8Bit(process.readAllStandardError()).trimmed();
    }
    return {};
}

DeviceDescriptor errorDescriptor(const QString &message)
{
    DeviceDescriptor error;
    error.device = "__error__";
    error.error = message.toStdString();
    return error;
}

} // namespace

std::vector<DeviceDescriptor> ListStorageDevices()
{
    QString commandError;
    const QByteArray output = runLsblk(commandError);
    if (output.isEmpty()) return {errorDescriptor(commandError)};

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return {errorDescriptor(QStringLiteral("Invalid lsblk JSON: %1").arg(parseError.errorString()))};

    std::vector<DeviceDescriptor> devices;
    for (const QJsonValue &entry : document.object().value(QStringLiteral("blockdevices")).toArray())
    {
        const QJsonObject node = entry.toObject();
        const QString type = node.value(QStringLiteral("type")).toString().toLower();
        const QString path = node.value(QStringLiteral("path")).toString();
        if (type != QStringLiteral("disk") || path.isEmpty() ||
            path.startsWith(QStringLiteral("/dev/loop")) ||
            path.startsWith(QStringLiteral("/dev/ram")) ||
            path.startsWith(QStringLiteral("/dev/zram")))
            continue;

        DeviceDescriptor device;
        device.device = device.raw = path.toStdString();
        device.devicePath = device.device;
        device.devicePathNull = false;
        device.size = unsignedValue(node.value(QStringLiteral("size")));
        device.blockSize = static_cast<uint32_t>(unsignedValue(
            node.value(QStringLiteral("phy-sec")), 512));
        device.logicalBlockSize = static_cast<uint32_t>(unsignedValue(
            node.value(QStringLiteral("log-sec")), 512));
        device.isReadOnly = booleanValue(node.value(QStringLiteral("ro")));

        const QString transport = node.value(QStringLiteral("tran")).toString().toUpper();
        const QString subsystems = node.value(QStringLiteral("subsystems")).toString().toLower();
        device.busType = transport.toStdString();
        device.enumerator = subsystems.toStdString();
        device.isUSB = transport == QStringLiteral("USB") || subsystems.contains(QStringLiteral("usb"));
        device.isUAS = device.isUSB && subsystems.contains(QStringLiteral("scsi"));
        device.isUASNull = false;
        device.isSCSI = !device.isUSB && (transport == QStringLiteral("SCSI") ||
                                          subsystems.contains(QStringLiteral("scsi")));
        device.isCard = transport == QStringLiteral("MMC") ||
                        path.startsWith(QStringLiteral("/dev/mmcblk"));
        device.isVirtual = subsystems == QStringLiteral("block") ||
                           path.startsWith(QStringLiteral("/dev/mapper/"));
        device.isRemovable = booleanValue(node.value(QStringLiteral("rm"))) ||
                             booleanValue(node.value(QStringLiteral("hotplug"))) ||
                             device.isUSB || device.isCard;

        QStringList labels;
        collectNode(device, node, labels);
        device.isSystem = !device.isRemovable && !device.isVirtual;
        for (const std::string &mountpoint : device.mountpoints)
            device.isSystem = device.isSystem || protectedMountpoint(mountpoint);

        QStringList description = {
            node.value(QStringLiteral("vendor")).toString().trimmed(),
            node.value(QStringLiteral("model")).toString().trimmed()
        };
        description.removeAll(QString());
        if (!labels.isEmpty()) description.append(QStringLiteral("(%1)").arg(labels.join(QStringLiteral(", "))));
        if (description.isEmpty()) description.append(path);
        device.description = description.join(QLatin1Char(' ')).toStdString();
        devices.push_back(device);
    }
    return devices;
}

} // namespace Drivelist
