/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include "driveformatthread.h"
#include "diskformatter.h"
#include "drivelist/drivelist.h"
#include "dependencies/mountutils/src/mountutils.hpp"
#include <regex>
#include <QDebug>
#include <QProcess>

#ifdef Q_OS_WIN
#include "windows/windowsdiskpreparation.h"
#endif

#ifdef Q_OS_LINUX
#include "linux/udisks2api.h"
#include <unistd.h>
#endif

DriveFormatThread::DriveFormatThread(const QByteArray &device, QObject *parent)
    : QThread(parent), _device(device)
{

}

DriveFormatThread::~DriveFormatThread()
{
    wait();
}

void DriveFormatThread::run()
{
#ifdef Q_OS_WIN
    std::regex windriveregex("\\\\\\\\.\\\\PHYSICALDRIVE([0-9]+)", std::regex_constants::icase);
    std::cmatch m;

    if (std::regex_match(_device.constData(), m, windriveregex))
    {
        const auto devices = Drivelist::ListStorageDevices();
        const QByteArray target = _device.toLower();
        const Drivelist::DeviceDescriptor *targetDevice = nullptr;
        if (!devices.empty() && devices.front().device == "__error__")
        {
            emit error(tr("Cannot enumerate the target drive: %1")
                       .arg(QString::fromStdString(devices.front().error)));
            return;
        }
        for (const Drivelist::DeviceDescriptor &device : devices)
        {
            if (QByteArray::fromStdString(device.device).toLower() == target)
            {
                targetDevice = &device;
                break;
            }
        }
        if (!targetDevice)
        {
            emit error(tr("The selected storage device is no longer available."));
            return;
        }
        if (targetDevice->isSystem)
        {
            emit error(tr("Refusing to format a system drive."));
            return;
        }

        WindowsDiskPreparation::LockedVolumes lockedVolumes;
        QString nativeError;
        if (!lockedVolumes.lockAndDismount(targetDevice->mountpoints, &nativeError))
        {
            emit error(tr("Cannot lock the target volumes: %1").arg(nativeError));
            return;
        }
        if (!WindowsDiskPreparation::clearPartitionTable(
                QString::fromUtf8(_device), &nativeError))
        {
            emit error(nativeError);
            return;
        }

        DiskFormatter formatter;
        const DiskFormatError formatResult =
            formatter.formatFat32(QString::fromUtf8(_device), QByteArray("SDCARD"));
        if (formatResult != DiskFormatError::Success)
        {
            emit error(tr("Error formatting: %1")
                       .arg(DiskFormatter::errorMessage(formatResult)));
            return;
        }
        lockedVolumes.release();
        if (!WindowsDiskPreparation::rescanDisk(QString::fromUtf8(_device), &nativeError))
        {
            emit error(nativeError);
            return;
        }
        const QString mountpoint = WindowsDiskPreparation::ensureDriveLetter(
            QString::fromUtf8(_device), 10000, &nativeError);
        if (mountpoint.isEmpty())
        {
            emit error(tr("Error determining new drive letter: %1").arg(nativeError));
            return;
        }
        emit success();
    }
    else
    {
        emit error(tr("Invalid device: %1").arg(QString(_device)));
    }
#elif defined(Q_OS_DARWIN)
    QProcess proc;
    QStringList args;
    args << "eraseDisk" << "FAT32" << "SDCARD" << "MBRFormat" << _device;
    proc.start("diskutil", args);
    proc.waitForFinished();

    QByteArray output = proc.readAllStandardError();
    qDebug() << args;
    qDebug() << "diskutil output:" << output;

    if (proc.exitCode())
    {
        emit error(tr("Error partitioning: %1").arg(QString(output)));
    }
    else
    {
        emit success();
    }

#elif defined(Q_OS_LINUX)

    if (::access(_device.constData(), W_OK) != 0)
    {
        /* Not running as root, try to outsource formatting to udisks2 */

#ifndef QT_NO_DBUS
        UDisks2Api udisks2;
        if (udisks2.formatDrive(_device))
        {
            emit success();
        }
        else
        {
#endif
            emit error(tr("Error formatting (through udisks2)"));
#ifndef QT_NO_DBUS
        }
#endif

        return;
    }


    QProcess proc;
    QByteArray partitionTable;
    QStringList args;
    QByteArray fatpartition = _device;
    partitionTable = "8192,,0E\n"
            "0,0\n"
            "0,0\n"
            "0,0\n";
    args << "-uS" << _device;
    if (isdigit(fatpartition.at(fatpartition.length()-1)))
        fatpartition += "p1";
    else
        fatpartition += "1";

    unmount_disk(_device);
    proc.setProcessChannelMode(proc.MergedChannels);
    proc.start("sfdisk", args);
    if (!proc.waitForStarted())
    {
        emit error(tr("Error starting sfdisk"));
        return;
    }
    proc.write(partitionTable);
    proc.closeWriteChannel();
    proc.waitForFinished();
    QByteArray output = proc.readAll();
    qDebug() << "sfdisk:" << output;

    if (proc.exitCode())
    {
        emit error(tr("Error partitioning: %1").arg(QString(output)));
        return;
    }

    proc.execute("partprobe", QStringList() );
    for (int tries = 0; tries < 30; tries++)
    {
        if (QFile::exists(fatpartition))
            break;

        QThread::msleep(100);
    }
    if (!QFile::exists(fatpartition))
    {
        emit error(tr("Partitioning did not create expected FAT partition %1").arg(QString(fatpartition)));
        return;
    }

    args.clear();
    args << fatpartition;
    proc.start("mkfs.fat", args);
    if (!proc.waitForStarted())
    {
        emit error(tr("Error starting mkfs.fat"));
        return;
    }

    proc.waitForFinished();
    output = proc.readAll();
    qDebug() << "mkfs.fat:" << output;

    if (proc.exitCode())
    {
        emit error(tr("Error running mkfs.fat: %1").arg(QString(output)));
        return;
    }

    emit success();

#else
    emit error(tr("Formatting not implemented for this platform"));
#endif
}
