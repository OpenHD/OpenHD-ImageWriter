/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "rockchipflashthread.h"
#include "rockchipdevice.h"

#include <QDebug>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTemporaryDir>
#include <archive.h>
#include <archive_entry.h>

RockchipFlashThread::RockchipFlashThread(const QUrl &source, const QString &deviceId, QObject *parent)
    : QThread(parent), _source(source), _deviceId(deviceId)
{
}
RockchipFlashThread::~RockchipFlashThread()
{
    cancel();
    wait();
}

void RockchipFlashThread::cancel()
{
    _cancelled = true;
}

bool RockchipFlashThread::extractZip(const QString &zipPath, const QString &destDir, QString *errorMsg)
{
    struct archive *a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);

    if (archive_read_open_filename(a, zipPath.toLocal8Bit().constData(), 65536) != ARCHIVE_OK)
    {
        if (errorMsg)
            *errorMsg = QString::fromUtf8(archive_error_string(a));
        archive_read_free(a);
        return false;
    }

    struct archive_entry *entry = nullptr;
    while (archive_read_next_header(a, &entry) == ARCHIVE_OK)
    {
        if (_cancelled)
            break;

        QString entryPath = QString::fromUtf8(archive_entry_pathname(entry));
        QString destFilePath = QDir(destDir).filePath(entryPath);

        if (archive_entry_filetype(entry) == AE_IFDIR)
        {
            QDir().mkpath(destFilePath);
            continue;
        }

        QFileInfo fi(destFilePath);
        QDir().mkpath(fi.path());

        QFile outFile(destFilePath);
        if (!outFile.open(QIODevice::WriteOnly))
            continue;

        char buffer[65536];
        la_ssize_t bytesRead = 0;
        while ((bytesRead = archive_read_data(a, buffer, sizeof(buffer))) > 0)
        {
            if (_cancelled)
                break;
            outFile.write(buffer, bytesRead);
        }
        outFile.close();
    }

    archive_read_close(a);
    archive_read_free(a);
    return !_cancelled;
}

void RockchipFlashThread::run()
{
    QTemporaryDir tempDir;
    if (!tempDir.isValid())
    {
        emit error(tr("Failed to create temporary working directory."));
        return;
    }

    QString localPackagePath;
    if (_source.isLocalFile())
    {
        localPackagePath = _source.toLocalFile();
    }
    else
    {
        emit preparationStatusUpdate(tr("Downloading firmware package..."));
        QNetworkAccessManager nam;
        QNetworkRequest req(_source);
        req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
        QNetworkReply *reply = nam.get(req);

        QEventLoop loop;
        connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 bytesReceived, qint64 bytesTotal) {
            if (_cancelled)
                return;
            if (bytesTotal > 0)
            {
                int pct = static_cast<int>(bytesReceived * 100 / bytesTotal);
                emit preparationStatusUpdate(tr("Downloading firmware package (%1%)...").arg(pct));
                emit writeProgress(bytesReceived, bytesTotal);
            }
        });

        loop.exec();

        if (_cancelled)
        {
            reply->abort();
            reply->deleteLater();
            return;
        }

        if (reply->error() != QNetworkReply::NoError)
        {
            emit error(tr("Failed to download firmware: %1").arg(reply->errorString()));
            reply->deleteLater();
            return;
        }

        QString fileName = _source.fileName();
        if (fileName.isEmpty())
            fileName = QStringLiteral("firmware.zip");
        localPackagePath = tempDir.filePath(fileName);

        QFile downloadFile(localPackagePath);
        if (!downloadFile.open(QIODevice::WriteOnly))
        {
            emit error(tr("Failed to save downloaded firmware."));
            reply->deleteLater();
            return;
        }
        downloadFile.write(reply->readAll());
        downloadFile.close();
        reply->deleteLater();
    }

    if (_cancelled)
        return;

    emit preparationStatusUpdate(tr("Inspecting firmware files..."));

    QString extractedDir = tempDir.path();
    QString lowerPath = localPackagePath.toLower();
    bool isZip = lowerPath.endsWith(QStringLiteral(".zip"));
    bool isOhd = lowerPath.endsWith(QStringLiteral(".ohd"));
    bool isRawImg = lowerPath.endsWith(QStringLiteral(".img"));

    if (isZip)
    {
        emit preparationStatusUpdate(tr("Extracting firmware package..."));
        QString extractErr;
        if (!extractZip(localPackagePath, extractedDir, &extractErr))
        {
            emit error(tr("Failed to extract firmware zip: %1").arg(extractErr));
            return;
        }
    }

    if (_cancelled)
        return;

    struct FlashTarget {
        QString name;
        quint32 lbaOffset;
        QString filePath;
        quint64 sizeBytes;
    };
    QList<FlashTarget> targets;
    QByteArray parameterData;

    // Check for parameter.txt
    QString paramPath = QDir(extractedDir).filePath(QStringLiteral("parameter.txt"));
    if (QFileInfo::exists(paramPath))
    {
        QFile pf(paramPath);
        if (pf.open(QIODevice::ReadOnly))
        {
            parameterData = pf.readAll();
            pf.close();
        }
    }

    if (!parameterData.isEmpty())
    {
        auto partitions = parseParameterTxt(parameterData);
        QDir d(extractedDir);
        for (const auto &part : partitions)
        {
            QString candidateName = part.name + QStringLiteral(".img");
            QString candidatePath = d.filePath(candidateName);
            if (!QFileInfo::exists(candidatePath))
            {
                // Try alternate names e.g. uboot_a -> uboot.img, boot_a -> boot.img, rootfs_a -> rootfs.img
                if (part.name.startsWith(QStringLiteral("uboot")))
                    candidatePath = d.filePath(QStringLiteral("uboot.img"));
                else if (part.name.startsWith(QStringLiteral("boot")))
                    candidatePath = d.filePath(QStringLiteral("boot.img"));
                else if (part.name.startsWith(QStringLiteral("rootfs")))
                    candidatePath = d.filePath(QStringLiteral("rootfs.img"));
            }

            if (QFileInfo::exists(candidatePath))
            {
                QFileInfo fi(candidatePath);
                FlashTarget target;
                target.name = part.name;
                target.lbaOffset = part.offset;
                target.filePath = candidatePath;
                target.sizeBytes = fi.size();
                targets.append(target);
            }
        }
    }
    else if (isOhd)
    {
        // Direct SWUpdate OpenHD NAND image -> LBA 0x0009a100 (sector 631040)
        FlashTarget target;
        target.name = QStringLiteral("ohd");
        target.lbaOffset = 0x0009a100;
        target.filePath = localPackagePath;
        target.sizeBytes = QFileInfo(localPackagePath).size();
        targets.append(target);
    }
    else if (isRawImg)
    {
        // Direct full disk image -> LBA 0x0
        FlashTarget target;
        target.name = QStringLiteral("image");
        target.lbaOffset = 0x0;
        target.filePath = localPackagePath;
        target.sizeBytes = QFileInfo(localPackagePath).size();
        targets.append(target);
    }
    else
    {
        // Look for any .img file in extracted directory
        QDir d(extractedDir);
        QStringList imgFiles = d.entryList(QStringList() << QStringLiteral("*.img"), QDir::Files);
        for (const QString &img : imgFiles)
        {
            FlashTarget target;
            target.name = QFileInfo(img).baseName();
            target.lbaOffset = (target.name.toLower() == QStringLiteral("ohd")) ? 0x0009a100 : 0x0;
            target.filePath = d.filePath(img);
            target.sizeBytes = QFileInfo(target.filePath).size();
            targets.append(target);
        }
    }

    if (targets.isEmpty() && parameterData.isEmpty())
    {
        emit error(tr("No flashable partition images found in the selected package."));
        return;
    }

    if (_cancelled)
        return;

    // Check device state
    emit preparationStatusUpdate(tr("Checking Rockchip device status..."));
    auto devices = listRockchipUsbDevices();
    bool deviceFound = false;
    bool isMaskrom = false;

    for (const auto &dev : devices)
    {
        if (dev.vendorId == 0x2207)
        {
            deviceFound = true;
            isMaskrom = dev.isMaskrom;
            break;
        }
    }

    if (!deviceFound)
    {
        emit error(tr("Rockchip device not detected. Please ensure your OpenHD X21 is connected via USB."));
        return;
    }

    if (isMaskrom)
    {
        emit preparationStatusUpdate(tr("OpenHD X21 detected in MaskROM mode. Loading bootloader..."));

        QByteArray bootloader;
        // Check if package contains MiniLoaderAll.bin
        QString customLoaderPath = QDir(extractedDir).filePath(QStringLiteral("MiniLoaderAll.bin"));
        if (QFileInfo::exists(customLoaderPath))
        {
            QFile lf(customLoaderPath);
            if (lf.open(QIODevice::ReadOnly))
            {
                bootloader = lf.readAll();
                lf.close();
            }
        }
        if (bootloader.isEmpty())
        {
            bootloader = loadDefaultBootloader();
        }

        if (bootloader.isEmpty())
        {
            emit error(tr("Failed to load Rockchip bootloader binary (MiniLoaderAll.bin)."));
            return;
        }

        QString dlErr;
        if (!downloadRockchipBootloader(bootloader, &dlErr))
        {
            emit error(tr("Failed to initialize bootloader: %1").arg(dlErr));
            return;
        }

        emit preparationStatusUpdate(tr("Waiting for device to re-enumerate in Loader mode..."));
        RockchipDeviceDescriptor loaderDesc;
        if (!waitForRockchipLoaderMode(15000, &loaderDesc))
        {
            emit error(tr("Timed out waiting for device to enter Loader mode after bootloader download."));
            return;
        }
    }

    if (_cancelled)
        return;

    emit preparationStatusUpdate(tr("Connecting to device in Loader mode..."));
    RockchipTransport transport;
    QString openErr;
    if (!transport.open(&openErr))
    {
        emit error(tr("Failed to connect to Loader interface: %1").arg(openErr));
        return;
    }

    // Calculate total bytes
    quint64 totalBytes = 0;
    if (!parameterData.isEmpty())
    {
        QByteArray paramBuf = makeParameterBuffer(parameterData);
        totalBytes += ((paramBuf.size() + 511) / 512) * 512;
    }
    for (const auto &t : targets)
    {
        totalBytes += ((t.sizeBytes + 511) / 512) * 512;
    }

    quint64 totalWritten = 0;
    emit writeProgress(0, totalBytes);

    // Flash parameter if present
    if (!parameterData.isEmpty())
    {
        emit preparationStatusUpdate(tr("Writing partition table (parameter.txt)..."));
        QByteArray paramBuf = makeParameterBuffer(parameterData);
        quint32 paramSectors = (paramBuf.size() + 511) / 512;
        QByteArray padded(paramSectors * 512, '\0');
        memcpy(padded.data(), paramBuf.constData(), paramBuf.size());

        QString writeErr;
        if (!transport.writeLBA(0x2000, paramSectors, reinterpret_cast<const quint8 *>(padded.constData()), &writeErr))
        {
            emit error(tr("Failed writing parameter partition: %1").arg(writeErr));
            transport.close();
            return;
        }
        totalWritten += padded.size();
        emit writeProgress(totalWritten, totalBytes);
    }

    // Flash partition targets
    constexpr quint16 ChunkSectors = 128; // 64 KB per USB transfer
    constexpr quint32 ChunkBytes = ChunkSectors * 512;
    QByteArray chunkBuffer(ChunkBytes, '\0');

    for (const auto &target : targets)
    {
        if (_cancelled)
            break;

        emit preparationStatusUpdate(tr("Flashing %1 (%2 MB)...")
                                     .arg(target.name)
                                     .arg(target.sizeBytes / (1024 * 1024)));

        QFile partFile(target.filePath);
        if (!partFile.open(QIODevice::ReadOnly))
        {
            emit error(tr("Unable to open image file: %1").arg(target.filePath));
            transport.close();
            return;
        }

        quint32 currentLba = target.lbaOffset;
        quint64 fileRemaining = target.sizeBytes;

        while (fileRemaining > 0 && !_cancelled)
        {
            chunkBuffer.fill('\0');
            qint64 readBytes = partFile.read(chunkBuffer.data(), ChunkBytes);
            if (readBytes <= 0)
                break;

            quint16 sectorsInChunk = static_cast<quint16>((readBytes + 511) / 512);
            QString writeErr;
            if (!transport.writeLBA(currentLba, sectorsInChunk,
                                   reinterpret_cast<const quint8 *>(chunkBuffer.constData()), &writeErr))
            {
                emit error(tr("Failed flashing %1 at sector %2: %3")
                           .arg(target.name).arg(currentLba).arg(writeErr));
                partFile.close();
                transport.close();
                return;
            }

            currentLba += sectorsInChunk;
            totalWritten += (sectorsInChunk * 512);
            fileRemaining = (fileRemaining > static_cast<quint64>(readBytes)) ? (fileRemaining - readBytes) : 0;
            emit writeProgress(totalWritten, totalBytes);
        }
        partFile.close();
    }

    if (_cancelled)
    {
        transport.close();
        return;
    }

    emit preparationStatusUpdate(tr("Flashing complete. Rebooting OpenHD device..."));
    emit finalizing();

    QString resetErr;
    transport.resetDevice(&resetErr);
    transport.close();

    emit success();
}
