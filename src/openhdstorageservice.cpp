#include "openhdstorageservice.h"

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "config.h"
#include "drivelist/drivelist.h"
#include "openhdstorageselector.h"
#ifdef Q_OS_WIN
#include "windows/windowsdiskpreparation.h"
#endif

#include <algorithm>

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStorageInfo>
#include <QThread>

QVariantList OpenHDStorageService::listTextFilesOnDevice(const QString &device)
{
    QVariantList files;

    if (device.isEmpty())
        return files;

    const QByteArray targetDeviceLower = device.toLower().toLatin1();
    const auto devices = Drivelist::ListStorageDevices();

    QStringList mountpoints;
    for (const auto &d : devices)
    {
        if (QByteArray::fromStdString(d.device).toLower() == targetDeviceLower)
        {
            for (const auto &mp : d.mountpoints)
            {
                QString mount = QString::fromStdString(mp);
                if (mount.endsWith('/') || mount.endsWith('\\'))
                    mount.chop(1);

                mountpoints.append(mount);
            }
            break;
        }
    }

    for (const QString &mountpoint : mountpoints)
    {
        QDir dir(mountpoint);
        const QFileInfoList entries = dir.entryInfoList(QStringList() << "*.txt",
                                                        QDir::Files | QDir::Readable,
                                                        QDir::Name | QDir::IgnoreCase);

        for (const QFileInfo &entry : entries)
        {
            QVariantMap fileEntry;
            fileEntry.insert("name", entry.fileName());
            fileEntry.insert("path", entry.absoluteFilePath());
            files.append(fileEntry);
        }
    }

    return files;
}

QString OpenHDStorageService::readTextFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();

    return QString::fromUtf8(file.readAll());
}

bool OpenHDStorageService::writeTextFile(const QString &filePath, const QString &content)
{
    const QFileInfo info(filePath);
    QDir dir = info.dir();
    if (!dir.exists() && !dir.mkpath("."))
    {
        qDebug() << "[OpenHDStorageService] Failed to create directory for" << filePath;
        return false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
    {
        qDebug() << "[OpenHDStorageService] Failed to open" << filePath << "for writing";
        return false;
    }

    const QByteArray data = content.toUtf8();
    return file.write(data) == data.size();
}

bool OpenHDStorageService::fileExists(const QString &filePath)
{
    return QFileInfo::exists(filePath);
}

bool OpenHDStorageService::copyFile(const QString &sourcePath, const QString &destinationPath)
{
    const QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile())
    {
        qDebug() << "[OpenHDStorageService] Source file does not exist" << sourcePath;
        return false;
    }

    const QFileInfo destinationInfo(destinationPath);
    QDir destinationDir = destinationInfo.dir();
    if (!destinationDir.exists() && !destinationDir.mkpath("."))
    {
        qDebug() << "[OpenHDStorageService] Failed to create directory for" << destinationPath;
        return false;
    }

    if (QFileInfo::exists(destinationPath) && !QFile::remove(destinationPath))
    {
        qDebug() << "[OpenHDStorageService] Failed to remove existing file" << destinationPath;
        return false;
    }

    if (!QFile::copy(sourcePath, destinationPath))
    {
        qDebug() << "[OpenHDStorageService] Failed to copy" << sourcePath << "to" << destinationPath;
        return false;
    }

    return true;
}

bool OpenHDStorageService::removeFile(const QString &filePath)
{
    if (!QFileInfo::exists(filePath))
        return true;

    QFile file(filePath);
    if (!file.remove())
    {
        qDebug() << "[OpenHDStorageService] Failed to remove file" << filePath;
        return false;
    }
    return true;
}

bool OpenHDStorageService::hasSettingsCard()
{
    const auto devices = Drivelist::ListStorageDevices();
    const bool filterSystemDrives = DRIVELIST_FILTER_SYSTEM_DRIVES;

    for (const auto &d : devices)
    {
        if (filterSystemDrives && d.isSystem)
            continue;
        if (d.size == 0)
            continue;

#ifdef Q_OS_DARWIN
        if (d.isVirtual)
            continue;
#endif

        for (const auto &mp : d.mountpoints)
        {
            QString mount = QString::fromStdString(mp);
            if (mount.isEmpty())
                continue;
            if (mount.endsWith('/') || mount.endsWith('\\'))
                mount.chop(1);

            const QString mountLower = mount.toLower();
            if (mountLower == "/" || mountLower.startsWith("c:\\") || mountLower.startsWith("c:/"))
                continue;

            const QStorageInfo storage(mount);
            if (!storage.isValid() || !storage.isReady())
                continue;

            const QString fsType = QString::fromLatin1(storage.fileSystemType()).toLower();
            if (fsType.contains("exfat"))
                continue;
            if (!fsType.contains("fat") && !fsType.contains("msdos"))
                continue;

            const QString settingsPath = QDir(mount).filePath("openhd/settings.json");
            if (QFileInfo::exists(settingsPath))
            {
                qDebug() << "[OpenHDStorageService] OpenHD settings detected at" << settingsPath;
                return true;
            }
        }
    }

    return false;
}

bool OpenHDStorageService::isOhdFile(const QUrl &url)
{
    QString path = url.isLocalFile() ? url.toLocalFile() : url.path();
    if (path.isEmpty())
        path = url.toString();
    return path.endsWith(QStringLiteral(".ohd"), Qt::CaseInsensitive);
}

QString OpenHDStorageService::findFatPartition(const QString &device)
{
    if (device.isEmpty())
        return QString();

    const QByteArray targetDeviceLower = device.toLower().toLatin1();
    auto devices = Drivelist::ListStorageDevices();

    const auto findDevice = [&](const std::vector<Drivelist::DeviceDescriptor> &deviceList) {
        return std::find_if(deviceList.begin(), deviceList.end(), [&](const Drivelist::DeviceDescriptor &candidate) {
            return QByteArray::fromStdString(candidate.device).toLower() == targetDeviceLower;
        });
    };

    auto deviceIt = findDevice(devices);

    // A freshly formatted volume may take a moment to receive a mount point.
    for (int retry = 0; retry < 3; ++retry)
    {
        if (deviceIt != devices.end() && !deviceIt->mountpoints.empty())
            break;

        QThread::msleep(400);
        devices = Drivelist::ListStorageDevices();
        deviceIt = findDevice(devices);
    }

#ifdef Q_OS_WIN
    if (deviceIt != devices.end() && deviceIt->mountpoints.empty())
    {
        QString nativeError;
        WindowsDiskPreparation::rescanDisk(device, &nativeError);
        const QString mountpoint = WindowsDiskPreparation::ensureDriveLetter(
            device, 5000, &nativeError);
        if (!mountpoint.isEmpty())
            return mountpoint;
        qWarning() << "[OpenHDStorageService] Could not mount FAT volume:" << nativeError;
    }
#endif

    if (deviceIt == devices.end() || deviceIt->mountpoints.empty())
        return QString();

    QStringList mountPoints;
    for (const auto &mp : deviceIt->mountpoints)
        mountPoints.append(QString::fromStdString(mp));

    return OpenHDStorageSelector::selectBestMountPoint(mountPoints);
}
