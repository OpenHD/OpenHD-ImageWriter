#include "drivelistmodelpollthread.h"
#include <QElapsedTimer>
#include <QDebug>

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

DriveListModelPollThread::DriveListModelPollThread(QObject *parent)
    : QThread(parent)
{
    qRegisterMetaType< std::vector<Drivelist::DeviceDescriptor> >( "std::vector<Drivelist::DeviceDescriptor>" );
    qRegisterMetaType< std::vector<RockchipDeviceDescriptor> >( "std::vector<RockchipDeviceDescriptor>" );
}

DriveListModelPollThread::~DriveListModelPollThread()
{
    stop();
    wait();
}

void DriveListModelPollThread::stop()
{
    _terminate.store(true);
    _wakeCondition.wakeAll();
}

void DriveListModelPollThread::start()
{
    if (isRunning())
        return;
    _terminate.store(false);
    QThread::start();
}

void DriveListModelPollThread::run()
{
    QElapsedTimer t1;

    while (!_terminate.load())
    {
        t1.start();
        emit newDriveList( Drivelist::ListStorageDevices() );
        if (_terminate.load())
            break;
        emit newRockchipDeviceList( listRockchipUsbDevices() );
        if (t1.elapsed() > 1000)
            qDebug() << "Enumerating drives took a long time:" << t1.elapsed()/1000.0 << "seconds";
        QMutexLocker locker(&_waitMutex);
        if (!_terminate.load())
            _wakeCondition.wait(&_waitMutex, 1000);
    }
}
