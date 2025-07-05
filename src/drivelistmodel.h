#ifndef DRIVELISTMODEL_H
#define DRIVELISTMODEL_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include <QAbstractItemModel>
#include <QMap>
#include <QHash>
#include <QSet>
#include "drivelistitem.h"
#include "drivelistmodelpollthread.h"

class DriveListModel : public QAbstractListModel
{
    Q_OBJECT
public:
    DriveListModel(QObject *parent = nullptr);
    virtual int rowCount(const QModelIndex &) const;
    virtual QHash<int, QByteArray> roleNames() const;
    virtual QVariant data(const QModelIndex &index, int role) const;
    void startPolling();
    void stopPolling();

    enum driveListRoles {
        deviceRole = Qt::UserRole + 1, descriptionRole, sizeRole, isNetRole, isUsbRole, isScsiRole, isReadOnlyRole, mountpointsRole
    };

public slots:
    void processDriveList(std::vector<Drivelist::DeviceDescriptor> l);
    
private:
    QStringList scanLocalDevices();

protected:
    QMap<QString,DriveListItem *> _drivelist;
    QHash<int, QByteArray> _rolenames;
    DriveListModelPollThread _thread;

    QSet<QString> _invalidXmlSources;
    QSet<QString> _virtualDriveSources;
    QMap<QString, Drivelist::DeviceDescriptor> _virtualDrives;
};

#endif // DRIVELISTMODEL_H
