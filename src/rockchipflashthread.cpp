/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "rockchipflashthread.h"
#include "archivepathvalidator.h"
#include "rockchipdevice.h"
#include "rockchipfirmwarelayout.h"
#include "rockchipimageverify.h"
#include "rockchipconfiguration.h"
#include "fatimagewriter.h"
#include "openhdimagecustomizer.h"

#include <QDebug>
#include <QBuffer>
#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSet>
#include <QSettings>
#include <QTemporaryDir>
#include <archive.h>
#include <archive_entry.h>

namespace {

QString packageLoaderPath(const QString &firmwareDirectory)
{
    const QStringList candidates = {QStringLiteral("MiniLoaderAll.bin"),
                                    QStringLiteral("download.bin")};
    for (const QString &name : candidates)
    {
        const QString path = QDir(firmwareDirectory).filePath(name);
        QFile loader(path);
        if (loader.open(QIODevice::ReadOnly) && loader.size() > 4 &&
            loader.read(4) == QByteArrayLiteral("LDR "))
            return path;
    }
    return {};
}

bool isReadableArchive(const QString &path)
{
    struct archive *reader = archive_read_new();
    archive_read_support_format_all(reader);
    archive_read_support_filter_all(reader);
    const int openResult = archive_read_open_filename(
            reader, path.toLocal8Bit().constData(), 65536);
    struct archive_entry *entry = nullptr;
    const int headerResult = openResult == ARCHIVE_OK
            ? archive_read_next_header(reader, &entry) : openResult;
    archive_read_close(reader);
    archive_read_free(reader);
    return headerResult == ARCHIVE_OK;
}

QStringList findFirmwareArchives(const QString &rootPath)
{
    QStringList matches;
    QDirIterator iterator(rootPath, QDir::Files | QDir::Readable,
                          QDirIterator::Subdirectories);
    while (iterator.hasNext())
    {
        const QFileInfo candidate(iterator.next());
        if (candidate.fileName().compare(QStringLiteral("firmware.zip"),
                                         Qt::CaseInsensitive) == 0)
            matches.append(candidate.absoluteFilePath());
    }
    return matches;
}

} // namespace

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
    constexpr int MaxEntries = 4096;
    constexpr quint64 MaxExtractedBytes = 64ULL * 1024 * 1024 * 1024;
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
    int entryCount = 0;
    quint64 extractedBytes = 0;
    QSet<QString> extractedPaths;
    int result = ARCHIVE_OK;
    while ((result = archive_read_next_header(a, &entry)) == ARCHIVE_OK)
    {
        if (_cancelled)
            break;

        if (++entryCount > MaxEntries)
        {
            if (errorMsg) *errorMsg = tr("Firmware archive contains too many entries.");
            archive_read_close(a);
            archive_read_free(a);
            return false;
        }

        const char *rawPath = archive_entry_pathname_utf8(entry);
        if (!rawPath)
            rawPath = archive_entry_pathname(entry);
        QString normalizedPath;
        QString pathError;
        if (!rawPath || !ArchivePathValidator::normalizeRelativePath(
                    QString::fromUtf8(rawPath), normalizedPath, &pathError))
        {
            if (errorMsg) *errorMsg = pathError;
            archive_read_close(a);
            archive_read_free(a);
            return false;
        }

        const auto fileType = archive_entry_filetype(entry);
        if ((fileType != AE_IFDIR && fileType != AE_IFREG) ||
            archive_entry_symlink(entry) || archive_entry_hardlink(entry))
        {
            if (errorMsg) *errorMsg = tr("Firmware archive contains a link or unsupported special file.");
            archive_read_close(a);
            archive_read_free(a);
            return false;
        }

        const QString pathKey = normalizedPath.toLower();
        if (extractedPaths.contains(pathKey))
        {
            if (errorMsg) *errorMsg = tr("Firmware archive contains duplicate paths.");
            archive_read_close(a);
            archive_read_free(a);
            return false;
        }
        extractedPaths.insert(pathKey);

        QString destFilePath = QDir(destDir).filePath(normalizedPath);

        if (fileType == AE_IFDIR)
        {
            if (!QDir().mkpath(destFilePath))
            {
                if (errorMsg) *errorMsg = tr("Unable to create a firmware package directory.");
                archive_read_close(a);
                archive_read_free(a);
                return false;
            }
            continue;
        }

        QFileInfo fi(destFilePath);
        if (!QDir().mkpath(fi.path()))
        {
            if (errorMsg) *errorMsg = tr("Unable to create a firmware package directory.");
            archive_read_close(a);
            archive_read_free(a);
            return false;
        }

        QFile outFile(destFilePath);
        if (!outFile.open(QIODevice::WriteOnly))
        {
            if (errorMsg) *errorMsg = tr("Unable to extract %1.").arg(normalizedPath);
            archive_read_close(a);
            archive_read_free(a);
            return false;
        }

        char buffer[65536];
        la_ssize_t bytesRead = 0;
        while ((bytesRead = archive_read_data(a, buffer, sizeof(buffer))) > 0)
        {
            if (_cancelled)
                break;
            extractedBytes += static_cast<quint64>(bytesRead);
            if (extractedBytes > MaxExtractedBytes || outFile.write(buffer, bytesRead) != bytesRead)
            {
                if (errorMsg) *errorMsg = extractedBytes > MaxExtractedBytes
                        ? tr("Firmware archive is too large.")
                        : tr("Unable to write extracted firmware data.");
                outFile.close();
                archive_read_close(a);
                archive_read_free(a);
                return false;
            }
        }
        outFile.close();
        if (bytesRead < 0)
        {
            if (errorMsg) *errorMsg = QString::fromUtf8(archive_error_string(a));
            archive_read_close(a);
            archive_read_free(a);
            return false;
        }
    }

    if (result != ARCHIVE_EOF && !_cancelled)
    {
        if (errorMsg) *errorMsg = QString::fromUtf8(archive_error_string(a));
        archive_read_close(a);
        archive_read_free(a);
        return false;
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
        QElapsedTimer downloadProgressTimer;
        downloadProgressTimer.start();

        QEventLoop loop;
        connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        connect(reply, &QNetworkReply::downloadProgress, this, [this, &downloadProgressTimer](qint64 bytesReceived, qint64 bytesTotal) {
            if (_cancelled)
                return;
            if (bytesTotal > 0 &&
                (bytesReceived >= bytesTotal || downloadProgressTimer.elapsed() >= 100))
            {
                downloadProgressTimer.restart();
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
    bool isOhd = lowerPath.endsWith(QStringLiteral(".ohd"));
    bool isRawImg = lowerPath.endsWith(QStringLiteral(".img"));
    // GitHub's artifact endpoint commonly ends in /download, so the URL and
    // temporary filename do not identify the ZIP. Inspect the downloaded
    // content instead.
    bool isFirmwarePackage = !isOhd && !isRawImg && isReadableArchive(localPackagePath);

    if (isFirmwarePackage)
    {
        const QString outerDirectory = tempDir.filePath(QStringLiteral("artifact"));
        if (!QDir().mkpath(outerDirectory))
        {
            emit error(tr("Unable to create the firmware extraction directory."));
            return;
        }

        emit preparationStatusUpdate(tr("Extracting downloaded artifact..."));
        QString extractErr;
        if (!extractZip(localPackagePath, outerDirectory, &extractErr))
        {
            emit error(tr("Failed to extract firmware archive: %1").arg(extractErr));
            return;
        }

        // X21 GitHub artifacts contain build logs and directory trees alongside
        // the real Rockchip payload. Only firmware.zip is a flashable package.
        const QStringList firmwareArchives = findFirmwareArchives(outerDirectory);
        if (firmwareArchives.size() > 1)
        {
            emit error(tr("The downloaded artifact contains more than one firmware.zip."));
            return;
        }

        QString layoutRoot = outerDirectory;
        if (firmwareArchives.size() == 1)
        {
            emit preparationStatusUpdate(tr("Found firmware.zip; extracting Rockchip partitions..."));
            layoutRoot = tempDir.filePath(QStringLiteral("firmware"));
            if (!QDir().mkpath(layoutRoot) ||
                !extractZip(firmwareArchives.first(), layoutRoot, &extractErr))
            {
                emit error(tr("Failed to extract firmware.zip: %1").arg(extractErr));
                return;
            }
        }

        QString layoutError;
        QString firmwareDirectory;
        if (!findRockchipFirmwareDirectory(layoutRoot, firmwareDirectory, &layoutError))
        {
            emit error(tr("Invalid Rockchip firmware package: %1").arg(layoutError));
            return;
        }
        extractedDir = firmwareDirectory;

        if (packageLoaderPath(extractedDir).isEmpty())
        {
            emit error(tr("The selected firmware ZIP does not contain a valid Rockchip loader (MiniLoaderAll.bin or download.bin)."));
            return;
        }

        emit preparationStatusUpdate(tr("Found Rockchip firmware in %1.")
                                     .arg(QDir(tempDir.path()).relativeFilePath(extractedDir)));
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
    QList<RockchipPartition> partitions;

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
        partitions = parseParameterTxt(parameterData);
        if (partitions.isEmpty())
        {
            emit error(tr("The firmware package contains an invalid or empty parameter.txt."));
            return;
        }
    }
    else if (isFirmwarePackage)
    {
        QFile environmentFile(QDir(extractedDir).filePath(QStringLiteral(".env.txt")));
        if (!environmentFile.open(QIODevice::ReadOnly))
        {
            emit error(tr("The firmware package does not contain readable partition metadata."));
            return;
        }
        partitions = parseBlockDeviceParts(environmentFile.readAll());
        if (partitions.isEmpty())
        {
            emit error(tr("The firmware package contains invalid or empty .env.txt partition metadata."));
            return;
        }
    }

    if (!partitions.isEmpty())
    {
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
                if (part.size > 0 && static_cast<quint64>(fi.size()) > static_cast<quint64>(part.size) * 512)
                {
                    emit error(tr("Firmware image %1 is larger than its %2 partition.")
                               .arg(fi.fileName(), part.name));
                    return;
                }
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

    if (targets.isEmpty())
    {
        emit error(tr("No flashable partition images found in the selected package."));
        return;
    }

    QSettings settings;
    if (settings.value("useSettings").toBool()) {
        // The transport subsequently verifies the complete customized image,
        // before resetting. Never edit a running/mounted target filesystem.
        QTemporaryDir staging;
        if (!staging.isValid()) { emit error(tr("Could not stage Rockchip configuration. Nothing has been flashed.")); return; }
        const auto result = OpenHDImageCustomizer::apply(staging.path(), settings);
        if (!result.succeeded()) {
            emit error(tr("Could not prepare Rockchip settings (error %1). %2 Nothing has been flashed.")
                       .arg(static_cast<int>(result.error)).arg(result.detail));
            return;
        }
        const QString role = OpenHDImageCustomizer::buildSettings(settings).value("role").toString();
        if (role == "air" || role == "ground") {
            QFile marker(QDir(staging.path()).filePath("openhd/" + role + ".txt"));
            if (!marker.open(QIODevice::WriteOnly)) {
                emit error(tr("Could not stage the selected device role. Nothing has been flashed.")); return;
            }
        }
        int targetIndex = -1;
        enum class ConfigKind { Fat, Disk, Ubi } kind = ConfigKind::Fat;
        for (int i = 0; i < targets.size(); ++i) {
            const auto name = targets.at(i).name.toLower();
            if (name != "ohd_config" && name != "disk" && name != "image" && name != "ohd") continue;
            if (targetIndex != -1) { emit error(tr("Ambiguous Rockchip configuration targets. Nothing has been flashed.")); return; }
            targetIndex = i;
            kind = name == "ohd_config" ? ConfigKind::Fat : name == "ohd" ? ConfigKind::Ubi : ConfigKind::Disk;
        }
        if (targetIndex == -1 || isOhd) {
            emit error(tr("This package cannot accept configuration through USB. Select a current full Luckfox/X21 firmware ZIP. Nothing has been flashed."));
            return;
        }
        auto &target = targets[targetIndex];
        // Direct raw sources belong to the user; copy before modifying.
        if (isRawImg) {
            const QString disposable = tempDir.filePath("configured-disk.img");
            if (!QFile::copy(target.filePath, disposable)) {
                emit error(tr("Could not copy the disk image for customization. Nothing has been flashed.")); return;
            }
            target.filePath = disposable;
        }
        emit preparationStatusUpdate(tr("Preparing Rockchip configuration before flashing..."));
        QString detail;
        const auto cancelled = [this]() { return _cancelled.load(); };
        bool ok = false;
        if (kind == ConfigKind::Fat) ok = FatImageWriter::install(target.filePath, staging.path(), &detail, cancelled);
        else if (kind == ConfigKind::Disk) ok = RockchipConfiguration::installDisk(target.filePath, staging.path(), &detail, cancelled);
        else ok = RockchipConfiguration::installUbi(target.filePath, staging.path(), &detail, cancelled);
        if (!ok) {
            if (!_cancelled) emit error(tr("Could not prepare Rockchip config: %1 Nothing has been flashed.").arg(detail));
            return;
        }
    }

    if (_cancelled)
        return;

    // Check device state
    emit preparationStatusUpdate(tr("Checking Rockchip device status..."));
    auto devices = listRockchipUsbDevices();
    bool deviceFound = false;
    bool isMaskrom = false;
    RockchipDeviceDescriptor selectedDevice;

    // The native transport opens the first Rockusb interface. Refuse an
    // ambiguous setup rather than flashing a different connected board.
    if (devices.size() > 1)
    {
        emit error(tr("Connect only the Rockchip device selected for flashing, then retry."));
        return;
    }

    for (const auto &dev : devices)
    {
        if (dev.vendorId == 0x2207 && dev.id == _deviceId)
        {
            deviceFound = true;
            isMaskrom = dev.isMaskrom;
            selectedDevice = dev;
            break;
        }
    }

    if (!deviceFound)
    {
        emit error(tr("The selected Rockchip device is not connected. Reconnect it and select it again."));
        return;
    }

    if (isOhd && selectedDevice.productId != 0x110f)
    {
        emit error(tr("This .ohd update uses the X21/RV1126B partition layout. Select a full firmware package for %1.")
                   .arg(selectedDevice.socName));
        return;
    }

    QByteArray bootloader;
    const QString customLoaderPath = packageLoaderPath(extractedDir);
    if (!customLoaderPath.isEmpty())
    {
        QFile loaderFile(customLoaderPath);
        if (loaderFile.open(QIODevice::ReadOnly))
            bootloader = loaderFile.readAll();
    }
    // Check package compatibility even if a loader is already running.
    if (!bootloader.isEmpty() && !rockchipLoaderMatchesDevice(
                bootloader, selectedDevice.vendorId, selectedDevice.productId))
    {
        emit error(tr("The firmware loader does not match the connected %1. Select firmware built for this device.")
                   .arg(selectedDevice.socName));
        return;
    }

    if (isMaskrom)
    {
        emit preparationStatusUpdate(tr("%1 detected in MaskROM mode. Loading bootloader...")
                                     .arg(selectedDevice.socName));

        // Full ImageBuilder firmware ZIPs are self-contained. Their loader
        // must match the firmware package and must never be substituted with
        // the copy embedded in ImageWriter.
        if (isFirmwarePackage && bootloader.isEmpty())
        {
            emit error(tr("The selected firmware ZIP does not contain a readable Rockchip loader."));
            return;
        }
        if (!isFirmwarePackage && bootloader.isEmpty())
        {
            bootloader = loadDefaultBootloader(selectedDevice.vendorId, selectedDevice.productId);
        }

        if (bootloader.isEmpty())
        {
            emit error(tr("A matching loader is required for %1 in MaskROM mode. Select a full firmware ZIP containing its MiniLoaderAll.bin or download.bin.")
                       .arg(selectedDevice.socName));
            return;
        }

        if (isFirmwarePackage)
        {
            emit preparationStatusUpdate(tr("Loading the Rockchip loader from the selected firmware ZIP..."));
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
    QElapsedTimer progressUpdateTimer;
    progressUpdateTimer.start();

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
            if (readBytes != static_cast<qint64>(qMin<quint64>(fileRemaining, ChunkBytes)))
            {
                emit error(tr("Unable to read the complete image: %1").arg(target.filePath));
                return;
            }

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
            // A 64 KiB transfer can complete thousands of times per image.
            // Queueing a QML update for every transfer starves the GUI thread.
            if (fileRemaining == 0 || progressUpdateTimer.elapsed() >= 100)
            {
                progressUpdateTimer.restart();
                emit writeProgress(totalWritten, totalBytes);
            }
        }
        partFile.close();
    }

    if (_cancelled)
    {
        transport.close();
        return;
    }

    // A successful bulk write is not proof that eMMC contains the image.
    // Verify every padded sector before reporting success or resetting.
    emit preparationStatusUpdate(tr("Verifying flashed image..."));
    if (!parameterData.isEmpty())
    {
        QByteArray parameter = makeParameterBuffer(parameterData);
        parameter.append(QByteArray((512 - parameter.size() % 512) % 512, '\0'));
        QBuffer source(&parameter);
        source.open(QIODevice::ReadOnly);
        QString verifyError;
        if (!verifyRockchipImage(source, parameter.size(), 0x2000,
                [&transport](quint32 lba, quint16 count, quint8 *data, QString *message) {
                    return transport.readLBA(lba, count, data, message);
                }, [this]() { return _cancelled.load(); }, &verifyError))
        {
            if (!_cancelled)
                emit error(tr("Failed verifying partition metadata: %1").arg(verifyError));
            return;
        }
    }
    quint64 verified = 0;
    for (const auto &target : targets)
    {
        QFile source(target.filePath);
        if (!source.open(QIODevice::ReadOnly))
        {
            emit error(tr("Unable to reopen image for verification: %1").arg(target.filePath));
            return;
        }
        QString verifyError;
        const bool valid = verifyRockchipImage(source, target.sizeBytes, target.lbaOffset,
            [&transport](quint32 lba, quint16 count, quint8 *data, QString *message) {
                return transport.readLBA(lba, count, data, message);
            }, [this]() { return _cancelled.load(); }, &verifyError,
            [this, &progressUpdateTimer, verified, totalBytes](quint64 done) {
                if (progressUpdateTimer.elapsed() >= 100) {
                    progressUpdateTimer.restart();
                    emit preparationStatusUpdate(tr("Verifying flashed image: %1%")
                        .arg((verified + done) * 100 / totalBytes));
                }
            });
        if (!valid)
        {
            if (!_cancelled)
                emit error(tr("Failed verifying %1: %2").arg(target.name, verifyError));
            return;
        }
        verified += target.sizeBytes;
    }

    emit preparationStatusUpdate(tr("Flashing complete. Rebooting OpenHD device..."));
    emit finalizing();

    // Persistent writes are complete at this point. Notify the UI before the
    // reset command because some Windows Rockusb drivers keep reset I/O
    // pending while the device disconnects and re-enumerates.
    emit success();

    QString resetErr;
    transport.resetDevice(&resetErr);
    transport.close();
}
