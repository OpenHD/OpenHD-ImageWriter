#ifndef DRIVELISTMODELPOLLTHREAD_H
#define DRIVELISTMODELPOLLTHREAD_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include <QThread>
#include <QMutex>
#include <QWaitCondition>
#include <atomic>
#include "drivelist/drivelist.h"
#include "rockchipdevice.h"

class DriveListModelPollThread : public QThread
{
    Q_OBJECT
public:
    DriveListModelPollThread(QObject *parent = nullptr);
    ~DriveListModelPollThread();
    void start();
    void stop();

protected:
    std::atomic<bool> _terminate{false};
    QMutex _waitMutex;
    QWaitCondition _wakeCondition;
    virtual void run() override;

signals:
    void newDriveList(std::vector<Drivelist::DeviceDescriptor> list);
    void newRockchipDeviceList(std::vector<RockchipDeviceDescriptor> list);
};

#endif // DRIVELISTMODELPOLLTHREAD_H
