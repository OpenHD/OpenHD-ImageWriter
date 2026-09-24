#ifndef DRIVELISTMODEL_H
#define DRIVELISTMODEL_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include <QAbstractItemModel>
#include <QMap>
#include <QHash>
#include "drivelistitem.h"
#include "drivelistmodelpollthread.h"

class DriveListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(bool showInternalDrives READ showInternalDrives WRITE setShowInternalDrives NOTIFY showInternalDrivesChanged)
public:
    DriveListModel(QObject *parent = nullptr);
    virtual int rowCount(const QModelIndex &) const;
    virtual QHash<int, QByteArray> roleNames() const;
    virtual QVariant data(const QModelIndex &index, int role) const;
    void startPolling();
    void stopPolling();
    bool showInternalDrives() const;
    void setShowInternalDrives(bool show);

    enum driveListRoles {
        deviceRole = Qt::UserRole + 1, descriptionRole, sizeRole, isUsbRole, isScsiRole, isReadOnlyRole, mountpointsRole,
        isMaskromRole, usbVendorIdRole, usbProductIdRole, isLoaderRole, socNameRole, boardNameRole
    };

public slots:
    void processDriveList(std::vector<Drivelist::DeviceDescriptor> l);
    void processRockchipDeviceList(std::vector<RockchipDeviceDescriptor> l);
signals:
    void showInternalDrivesChanged();
protected:
    QMap<QString,DriveListItem *> _drivelist;
    QHash<int, QByteArray> _rolenames;
    DriveListModelPollThread _thread;
    std::vector<Drivelist::DeviceDescriptor> _lastDriveList;
    bool _showInternalDrives;
};

#endif // DRIVELISTMODEL_H
