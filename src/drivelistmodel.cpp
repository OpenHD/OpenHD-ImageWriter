/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include "drivelistmodel.h"
#include "config.h"
#include "drivesafetypolicy.h"
#include "drivelist/drivelist.h"
#include <QSet>
#include <QDebug>

DriveListModel::DriveListModel(QObject *parent)
    : QAbstractListModel(parent)
{
    _rolenames = {
        {deviceRole, "device"},
        {descriptionRole, "description"},
        {sizeRole, "size"},
        {isUsbRole, "isUsb"},
        {isScsiRole, "isScsi"},
        {isReadOnlyRole, "isReadOnly"},
        {mountpointsRole, "mountpoints"},
        {isMaskromRole, "isMaskrom"},
        {usbVendorIdRole, "usbVendorId"},
        {usbProductIdRole, "usbProductId"},
        {isLoaderRole, "isLoader"},
        {socNameRole, "socName"},
        {boardNameRole, "boardName"}
    };

    // Enumerate drives in seperate thread, but process results in UI thread
    connect(&_thread, SIGNAL(newDriveList(std::vector<Drivelist::DeviceDescriptor>)), SLOT(processDriveList(std::vector<Drivelist::DeviceDescriptor>)));
    connect(&_thread, SIGNAL(newRockchipDeviceList(std::vector<RockchipDeviceDescriptor>)), SLOT(processRockchipDeviceList(std::vector<RockchipDeviceDescriptor>)));
}

int DriveListModel::rowCount(const QModelIndex &) const
{
    return _drivelist.count();
}

QHash<int, QByteArray> DriveListModel::roleNames() const
{
    return _rolenames;
}

QVariant DriveListModel::data(const QModelIndex &index, int role) const
{
    int row = index.row();
    if (row < 0 || row >= _drivelist.count())
        return QVariant();

    QByteArray propertyName = _rolenames.value(role);
    if (propertyName.isEmpty())
        return QVariant();
    else
        return _drivelist.values().at(row)->property(propertyName);
}

void DriveListModel::processDriveList(std::vector<Drivelist::DeviceDescriptor> l)
{
    if (!l.empty() && l.front().device == "__error__" &&
        !l.front().error.empty())
    {
        qWarning() << "Drive enumeration failed; retaining the previous list:"
                   << QString::fromStdString(l.front().error);
        return;
    }

    bool changes = false;
    bool filterSystemDrives = DRIVELIST_FILTER_SYSTEM_DRIVES;
    QSet<QString> drivesInNewList;

    for (auto &i: l)
    {
        // Convert STL vector<string> to Qt QStringList
        QStringList mountpoints;
        for (auto &s: i.mountpoints)
        {
            mountpoints.append(QString::fromStdString(s));
        }

        DriveCandidate candidate;
        candidate.device = QString::fromStdString(i.device);
        candidate.description = QString::fromStdString(i.description);
        candidate.busType = QString::fromStdString(i.busType);
        candidate.enumerator = QString::fromStdString(i.enumerator);
        candidate.mountpoints = mountpoints;
        candidate.size = i.size;
        candidate.readOnly = i.isReadOnly;
        candidate.system = i.isSystem;
        candidate.virtualDevice = i.isVirtual;
        candidate.removable = i.isRemovable;
        candidate.usb = i.isUSB;
        candidate.uas = !i.isUASNull && i.isUAS;
        candidate.scsi = i.isSCSI;
        const SafeDrive safeDrive = DriveSafetyPolicy::evaluate(candidate);
        if (!safeDrive.displayable || (filterSystemDrives && safeDrive.system))
            continue;

        const QString deviceNamePlusSize = safeDrive.key;
        drivesInNewList.insert(deviceNamePlusSize);

        if (!_drivelist.contains(deviceNamePlusSize))
        {
            // Found new drive
            if (!changes)
            {
                beginResetModel();
                changes = true;
            }

            _drivelist[deviceNamePlusSize] = new DriveListItem(
                candidate.device, safeDrive.description, i.size, safeDrive.usb,
                safeDrive.scsi, i.isReadOnly, mountpoints, this);
        }
    }

    // Look for drives removed
    QStringList drivesInOldList = _drivelist.keys();
    for (auto &device: drivesInOldList)
    {
        if (!device.startsWith(QStringLiteral("rockusb:")) && !drivesInNewList.contains(device))
        {
            if (!changes)
            {
                beginResetModel();
                changes = true;
            }

            _drivelist.value(device)->deleteLater();
            _drivelist.remove(device);
        }
    }

    if (changes)
        endResetModel();
}

void DriveListModel::processRockchipDeviceList(std::vector<RockchipDeviceDescriptor> l)
{
    bool changes = false;
    QSet<QString> devicesInNewList;

    for (const RockchipDeviceDescriptor &device : l)
    {
        const QString key = QStringLiteral("rockusb:") + device.id;
        devicesInNewList.insert(key);
        if (_drivelist.contains(key))
            continue;

        if (!changes)
        {
            beginResetModel();
            changes = true;
        }

        QString description;
        if (!device.displayName.isEmpty())
        {
            description = device.displayName;
        }
        else
        {
            description = tr("Rockchip %1 (%2:%3)")
                    .arg(device.isMaskrom ? tr("MaskROM") : tr("Loader"))
                    .arg(device.vendorId, 4, 16, QLatin1Char('0'))
                    .arg(device.productId, 4, 16, QLatin1Char('0'));
        }

        _drivelist[key] = new DriveListItem(device.id, description, 0, true, false, false,
                                             {}, device.isMaskrom, device.vendorId, device.productId,
                                             device.isLoader, device.socName, device.displayName, this);
    }

    const QStringList oldKeys = _drivelist.keys();
    for (const QString &key : oldKeys)
    {
        if (key.startsWith(QStringLiteral("rockusb:")) && !devicesInNewList.contains(key))
        {
            if (!changes)
            {
                beginResetModel();
                changes = true;
            }
            _drivelist.value(key)->deleteLater();
            _drivelist.remove(key);
        }
    }

    if (changes)
        endResetModel();
}

void DriveListModel::startPolling()
{
    _thread.start();
}

void DriveListModel::stopPolling()
{
    _thread.stop();
}
