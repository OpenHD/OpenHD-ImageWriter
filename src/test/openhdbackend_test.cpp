/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "openhdimagecustomizer.h"
#include "archivepathvalidator.h"
#include "openhdstorageselector.h"
#include "file_operations.h"
#include "blockbatcher.h"
#include "curlretrypolicy.h"
#include "drivesafetypolicy.h"
#include "diskformatter.h"
#include "ringbuffer.h"
#include "rockchipfirmwarelayout.h"
#include "writeprogresswatchdog.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QList>
#include <QSettings>
#include <QTemporaryDir>

#include <cstring>

#include <QtEndian>

namespace {

bool check(bool condition, const QString &message)
{
    if (!condition)
        qCritical().noquote() << message;
    return condition;
}

bool writeFile(const QString &path, const QByteArray &contents)
{
    QFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(contents) == contents.size();
}

bool testGroundSettingsAndCameraMapping()
{
    QTemporaryDir temporaryDirectory;
    QSettings settings(temporaryDirectory.filePath("settings.ini"), QSettings::IniFormat);
    settings.setValue("sbc", "rpi");
    settings.setValue("camera", "IMX219");
    settings.setValue("camera2", "IP-CAMERA");
    settings.setValue("cameraPort", "cam0");
    settings.setValue("camera2Resolution", "1920x1080@30");
    settings.setValue("camera2IpCameraAddress", "10.0.0.2");
    settings.setValue("bootType", "Ground");
    settings.setValue("displayForceMode", true);
    settings.setValue("displayWidth", 100);       // Verify lower clamp.
    settings.setValue("displayHeight", 9000);    // Verify upper clamp.
    settings.setValue("displayRefreshHz", 5);    // Verify lower clamp.

    const QJsonObject result = OpenHDImageCustomizer::buildSettings(settings);
    return check(result.value("camera").toString() == "31", "IMX219 mapping changed") &&
           check(result.value("camera2").toString() == "3", "IP camera mapping changed") &&
           check(result.value("camera_port").toString() == "cam0", "Raspberry Pi camera port was lost") &&
           check(result.value("camera2_ip_camera_address").toString() == "10.0.0.2", "Second IP camera address was lost") &&
           check(result.value("role").toString() == "ground", "Ground role was not generated") &&
           check(result.value("display_force_mode").toBool(), "Forced display mode was not generated") &&
           check(result.value("display_width").toInt() == 320, "Display width was not clamped") &&
           check(result.value("display_height").toInt() == 4320, "Display height was not clamped") &&
           check(result.value("display_refresh_hz").toInt() == 20, "Display refresh was not clamped") &&
           check(result.value("display_connector").toString() == "HDMI-A-1", "Display connector changed");
}

bool testImageNameRoleOverrides()
{
    QTemporaryDir temporaryDirectory;
    QSettings settings(temporaryDirectory.filePath("settings.ini"), QSettings::IniFormat);
    settings.setValue("bootType", "Ground");
    settings.setValue("fileName", "OpenHD-X20-release.img.xz");

    const QJsonObject x20Result = OpenHDImageCustomizer::buildSettings(settings);
    if (!check(x20Result.value("role").toString() == "air", "X20 image no longer forces the Air role"))
        return false;

    settings.setValue("bootType", "Air");
    settings.setValue("fileName", "OpenHD-minimal.img.xz");
    const QJsonObject minimalResult = OpenHDImageCustomizer::buildSettings(settings);
    return check(minimalResult.value("role").toString() == "ground", "Minimal image no longer forces the Ground role");
}

bool testCustomizationInstall()
{
    QTemporaryDir temporaryDirectory;
    const QString bootPartition = temporaryDirectory.filePath("boot");
    if (!QDir().mkpath(bootPartition))
        return check(false, "Could not create temporary boot partition");

    const QString sourceConfig = temporaryDirectory.filePath("QOpenHD-source.conf");
    if (!writeFile(sourceConfig, "test-setting=true\n"))
        return check(false, "Could not create temporary QOpenHD.conf");

    QSettings settings(temporaryDirectory.filePath("settings.ini"), QSettings::IniFormat);
    settings.setValue("bootType", "Air");
    settings.setValue("qopenhdConfPath", sourceConfig);

    const OpenHDImageCustomizer::Result result = OpenHDImageCustomizer::apply(bootPartition, settings);
    if (!check(result.succeeded(), "Valid customization failed to install"))
        return false;

    QFile settingsFile(QDir(bootPartition).filePath("openhd/settings.json"));
    if (!check(settingsFile.open(QIODevice::ReadOnly), "settings.json was not created"))
        return false;
    const QJsonObject json = QJsonDocument::fromJson(settingsFile.readAll()).object();

    QFile copiedConfig(QDir(bootPartition).filePath("openhd/QOpenHD.conf"));
    if (!check(copiedConfig.open(QIODevice::ReadOnly), "QOpenHD.conf was not copied"))
        return false;

    return check(json.value("role").toString() == "air", "Installed settings.json has the wrong role") &&
           check(copiedConfig.readAll() == "test-setting=true\n", "Installed QOpenHD.conf contents changed");
}

bool testInvalidCertificateRejected()
{
    QTemporaryDir temporaryDirectory;
    const QString bootPartition = temporaryDirectory.filePath("boot");
    QDir().mkpath(bootPartition);
    const QString certificate = temporaryDirectory.filePath("invalid.ohdcert");
    writeFile(certificate, "version=invalid\n");

    QSettings settings(temporaryDirectory.filePath("settings.ini"), QSettings::IniFormat);
    settings.setValue("premiumCertificatePath", certificate);
    const OpenHDImageCustomizer::Result result = OpenHDImageCustomizer::apply(bootPartition, settings);

    return check(result.error == OpenHDImageCustomizer::Error::InvalidCertificate,
                 "Invalid premium certificate was not rejected") &&
           check(!QFile::exists(QDir(bootPartition).filePath("openhd/premium_certificate.ohdcert")),
                 "Invalid premium certificate was installed");
}

bool testStorageSelection()
{
    QTemporaryDir temporaryDirectory;
    const QString settingsVolume = temporaryDirectory.filePath("settings-volume");
    const QString updateVolume = temporaryDirectory.filePath("update-volume");
    QDir().mkpath(QDir(settingsVolume).filePath("openhd"));
    QDir().mkpath(updateVolume);
    writeFile(QDir(settingsVolume).filePath("openhd/settings.json"), "{}");
    writeFile(QDir(updateVolume).filePath("config.txt"), "# OpenHD\n");

    QString selected = OpenHDStorageSelector::selectBestMountPoint({updateVolume, settingsVolume});
    if (!check(selected == settingsVolume, "settings.json volume was not preferred"))
        return false;

    writeFile(QDir(updateVolume).filePath("release.ohd"), "update");
    selected = OpenHDStorageSelector::selectBestMountPoint({settingsVolume, updateVolume});
    return check(selected == updateVolume, ".ohd plus config.txt volume was not preferred") &&
           check(OpenHDStorageSelector::selectBestMountPoint({temporaryDirectory.filePath("missing")}).isEmpty(),
                 "Missing mount point was selected");
}

bool testPlatformFileOperations()
{
    QTemporaryDir temporaryDirectory;
    const QString imagePath = temporaryDirectory.filePath("scratch.img");
    if (!writeFile(imagePath, QByteArray(4096, '\0')))
        return check(false, "Could not create scratch image");

    std::unique_ptr<FileOperations> file = FileOperations::create();
    if (!check(file->openDevice(imagePath, true) == FileError::Success,
               "Could not exclusively open scratch image"))
        return false;

    std::unique_ptr<FileOperations> competingFile = FileOperations::create();
    if (!check(competingFile->openDevice(imagePath, true) == FileError::Busy,
               "Exclusive open did not reject a competing writer"))
        return false;

    const QByteArray payload("OpenHD file operations");
    std::size_t bytesWritten = 0;
    if (!check(file->writeSequential(reinterpret_cast<const quint8 *>(payload.constData()),
                                     static_cast<std::size_t>(payload.size()), bytesWritten) == FileError::Success,
               "Sequential write failed") ||
        !check(bytesWritten == static_cast<std::size_t>(payload.size()), "Sequential write was partial") ||
        !check(file->position() == static_cast<quint64>(payload.size()), "Write position is incorrect") ||
        !check(file->flush() == FileError::Success, "Flush failed"))
        return false;

    quint64 imageSize = 0;
    if (!check(file->size(imageSize) == FileError::Success && imageSize == 4096,
               "Native size detection failed") ||
        !check(file->seek(0) == FileError::Success, "Seek failed"))
        return false;

    QByteArray readBack(payload.size(), '\0');
    std::size_t bytesRead = 0;
    if (!check(file->readSequential(reinterpret_cast<quint8 *>(readBack.data()),
                                    static_cast<std::size_t>(readBack.size()), bytesRead) == FileError::Success,
               "Sequential read failed") ||
        !check(bytesRead == static_cast<std::size_t>(payload.size()) && readBack == payload,
               "Read-back verification failed"))
        return false;

    file->cancel();
    bytesWritten = 0;
    if (!check(file->writeSequential(reinterpret_cast<const quint8 *>(payload.constData()),
                                     static_cast<std::size_t>(payload.size()), bytesWritten) == FileError::Cancelled,
               "Cancellation did not stop a write"))
        return false;

    file->resetCancellation();
    return check(file->close() == FileError::Success, "Close failed") &&
           check(!file->isOpen(), "File remained open after close");
}

bool testRingBufferFlowAndBackpressure()
{
    RingBuffer buffer(2, 8);
    quint8 *firstWrite = buffer.acquireWriteSlot(0);
    if (!check(firstWrite != nullptr, "Could not acquire first ring-buffer write slot"))
        return false;
    memcpy(firstWrite, "first", 5);
    if (!check(buffer.commitWrite(5), "Could not commit first ring-buffer slot"))
        return false;

    quint8 *secondWrite = buffer.acquireWriteSlot(0);
    if (!check(secondWrite != nullptr, "Could not acquire second ring-buffer write slot"))
        return false;
    memcpy(secondWrite, "second", 6);
    if (!check(buffer.commitWrite(6), "Could not commit second ring-buffer slot") ||
        !check(buffer.acquireWriteSlot(1) == nullptr, "Full ring buffer did not apply backpressure"))
        return false;

    std::size_t bytesRead = 0;
    const quint8 *firstRead = buffer.acquireReadSlot(bytesRead, 0);
    if (!check(firstRead != nullptr && bytesRead == 5 && memcmp(firstRead, "first", 5) == 0,
               "First ring-buffer slot was corrupted") ||
        !check(buffer.releaseReadSlot(), "Could not release first ring-buffer slot"))
        return false;

    const quint8 *secondRead = buffer.acquireReadSlot(bytesRead, 0);
    if (!check(secondRead != nullptr && bytesRead == 6 && memcmp(secondRead, "second", 6) == 0,
               "Second ring-buffer slot was corrupted") ||
        !check(buffer.releaseReadSlot(), "Could not release second ring-buffer slot") ||
        !check(buffer.pendingSlots() == 0, "Ring buffer did not drain"))
        return false;

    buffer.cancel();
    return check(buffer.acquireReadSlot(bytesRead, 0) == nullptr, "Cancelled ring buffer still allowed reads") &&
           check(buffer.reset(), "Drained ring buffer could not be reset") &&
           check(!buffer.isCancelled(), "Ring-buffer cancellation was not reset");
}

bool testBlockBatching()
{
    QByteArray output;
    QList<int> writeSizes;
    BlockBatcher batcher(8, [&](const quint8 *data, std::size_t size) {
        output.append(reinterpret_cast<const char *>(data), static_cast<int>(size));
        writeSizes.append(static_cast<int>(size));
        return true;
    });

    const QByteArray first("abc");
    const QByteArray second("defghijkl");
    if (!check(batcher.append(reinterpret_cast<const quint8 *>(first.constData()), first.size()),
               "Could not append first archive block") ||
        !check(batcher.append(reinterpret_cast<const quint8 *>(second.constData()), second.size()),
               "Could not append second archive block") ||
        !check(writeSizes == QList<int>({8}), "Block batcher emitted an unexpected full batch") ||
        !check(batcher.pendingBytes() == 4, "Block batcher retained the wrong byte count") ||
        !check(batcher.flush(), "Could not flush final partial batch"))
        return false;

    return check(output == first + second, "Block batching changed the byte stream") &&
           check(writeSizes == QList<int>({8, 4}), "Block batching emitted incorrect write sizes");
}

bool testWriteProgressWatchdog()
{
    WriteProgressWatchdog::Configuration configuration;
    configuration.warningAfterMs = 10;
    configuration.recoverAfterMs = 20;
    configuration.hardTimeoutAfterMs = 40;
    WriteProgressWatchdog watchdog(configuration);

    WriteProgressWatchdog::Snapshot snapshot;
    watchdog.start(100, snapshot);
    snapshot.deviceOperationActive = true;
    if (!check(watchdog.observe(101, snapshot) == WriteProgressWatchdog::Action::None,
               "Watchdog treated operation start as a stall") ||
        !check(watchdog.observe(111, snapshot) == WriteProgressWatchdog::Action::Warn,
               "Watchdog did not warn about a stalled write") ||
        !check(watchdog.observe(121, snapshot) == WriteProgressWatchdog::Action::RequestRecovery,
               "Watchdog did not request write recovery") ||
        !check(watchdog.observe(141, snapshot) == WriteProgressWatchdog::Action::HardTimeout,
               "Watchdog did not report the hard timeout"))
        return false;

    snapshot.deviceOperationActive = false;
    if (!check(watchdog.observe(142, snapshot) == WriteProgressWatchdog::Action::None,
               "Inactive device operation remained stalled"))
        return false;
    snapshot.written = 1024;
    snapshot.deviceOperationActive = true;
    return check(watchdog.observe(143, snapshot) == WriteProgressWatchdog::Action::None,
                 "Fresh write progress did not reset the watchdog");
}

bool testCurlRetryPolicy()
{
    CurlRetryPolicy policy(8);
    if (!check(policy.next(CURLE_COULDNT_CONNECT, false) ==
                   CurlRetryPolicy::Action::RetryWithIPv4,
               "Initial connection failure did not trigger IPv4 fallback") ||
        !check(policy.next(CURLE_SSL_CONNECT_ERROR, false) ==
                   CurlRetryPolicy::Action::RetryWithHttp11,
               "TLS failure did not trigger HTTP/1.1 fallback") ||
        !check(policy.next(CURLE_PARTIAL_FILE, true) == CurlRetryPolicy::Action::Retry,
               "Partial transfer was not resumable") ||
        !check(policy.next(CURLE_RECV_ERROR, false) == CurlRetryPolicy::Action::Stop,
               "Receive error without progress was retried"))
        return false;

    CurlRetryPolicy boundedPolicy(2);
    if (!check(boundedPolicy.next(CURLE_PARTIAL_FILE, true) == CurlRetryPolicy::Action::Retry,
                 "First bounded retry was rejected") ||
        !check(boundedPolicy.next(CURLE_PARTIAL_FILE, true) == CurlRetryPolicy::Action::Retry,
               "Second bounded retry was rejected"))
        return false;
    if (!check(boundedPolicy.next(CURLE_PARTIAL_FILE, true) == CurlRetryPolicy::Action::Stop,
               "Retry limit was not enforced"))
        return false;

    CurlRetryPolicy http2Policy;
    return check(http2Policy.next(CURLE_HTTP2_STREAM, false) == CurlRetryPolicy::Action::Retry,
                 "First HTTP/2 stream retry was rejected") &&
           check(http2Policy.next(CURLE_HTTP2_STREAM, false) == CurlRetryPolicy::Action::Retry,
                 "Second HTTP/2 stream retry was rejected") &&
           check(http2Policy.next(CURLE_HTTP2_STREAM, false) ==
                     CurlRetryPolicy::Action::RetryWithHttp11,
                 "Repeated HTTP/2 stream errors did not fall back to HTTP/1.1");
}

bool testArchivePathValidation()
{
    QString normalized;
    QString error;
    if (!check(ArchivePathValidator::normalizeRelativePath(
                   QStringLiteral("openhd/config/settings.json"), normalized, &error),
               "Valid archive path was rejected") ||
        !check(normalized == QStringLiteral("openhd/config/settings.json"),
               "Valid archive path changed unexpectedly"))
        return false;

    const QStringList unsafePaths = {
        QStringLiteral("../outside"), QStringLiteral("openhd/../../outside"),
        QStringLiteral("/absolute/path"), QStringLiteral("C:\\absolute\\path"),
        QStringLiteral("\\\\server\\share\\file")
    };
    for (const QString &path : unsafePaths)
    {
        if (!check(!ArchivePathValidator::normalizeRelativePath(path, normalized, &error),
                   QStringLiteral("Unsafe archive path was accepted: %1").arg(path)))
            return false;
    }
    return true;
}

bool testDriveSafetyPolicy()
{
    DriveCandidate candidate;
    candidate.device = QStringLiteral("\\\\.\\PHYSICALDRIVE7");
    candidate.description = QStringLiteral("Trusted") + QChar(0x202e) + QStringLiteral("USB");
    candidate.busType = QStringLiteral("SCSI");
    candidate.enumerator = QStringLiteral("UASPSTOR");
    candidate.size = 32000000000ULL;
    candidate.removable = true;
    candidate.uas = true;
    candidate.scsi = true;
    SafeDrive drive = DriveSafetyPolicy::evaluate(candidate);
    if (!check(drive.displayable, "Removable UASP drive was hidden") ||
        !check(drive.usb && !drive.scsi, "UASP drive was not classified as USB") ||
        !check(!drive.description.contains(QChar(0x202e)),
               "Bidirectional control remained in drive description"))
        return false;

    candidate.mountpoints = QStringList() << QStringLiteral("C:\\");
    drive = DriveSafetyPolicy::evaluate(candidate);
    if (!check(drive.system, "Windows system mount was not protected"))
        return false;

    candidate.mountpoints.clear();
    candidate.virtualDevice = true;
    candidate.removable = false;
    drive = DriveSafetyPolicy::evaluate(candidate);
    return check(!drive.displayable, "Non-removable virtual disk was exposed as a target");
}

bool testDiskFormatter()
{
    QTemporaryDir temporaryDirectory;
    const QString path = temporaryDirectory.filePath(QStringLiteral("fat32.img"));
    QFile image(path);
    const qint64 imageSize = 64LL * 1024 * 1024;
    if (!check(image.open(QIODevice::ReadWrite) && image.resize(imageSize),
               "Could not create FAT32 formatter scratch image"))
        return false;
    image.close();

    DiskFormatter formatter;
    if (!check(formatter.formatFat32(path, QByteArray("OPENHD")) ==
                   DiskFormatError::Success,
               "Native FAT32 formatter failed"))
        return false;

    if (!check(image.open(QIODevice::ReadOnly), "Could not inspect formatted image"))
        return false;
    const QByteArray mbr = image.read(512);
    image.seek(8192LL * 512);
    const QByteArray boot = image.read(512);
    const QByteArray fsInfo = image.read(512);
    image.seek((8192LL + 6) * 512);
    const QByteArray backupBoot = image.read(512);
    image.seek((8192LL + 32) * 512);
    const QByteArray fatStart = image.read(12);
    if (!check(mbr.size() == 512 && boot.size() == 512 && fsInfo.size() == 512,
               "Formatted image metadata was truncated"))
        return false;

    const quint32 firstLba = qFromLittleEndian<quint32>(
        reinterpret_cast<const uchar *>(mbr.constData() + 454));
    const quint32 hiddenSectors = qFromLittleEndian<quint32>(
        reinterpret_cast<const uchar *>(boot.constData() + 28));
    const quint32 fsInfoLead = qFromLittleEndian<quint32>(
        reinterpret_cast<const uchar *>(fsInfo.constData()));
    const quint32 firstFatEntry = qFromLittleEndian<quint32>(
        reinterpret_cast<const uchar *>(fatStart.constData()));
    return check(static_cast<uchar>(mbr.at(450)) == 0x0C,
                 "Formatter produced the wrong MBR partition type") &&
           check(firstLba == 8192, "Formatter produced the wrong partition offset") &&
           check(static_cast<uchar>(mbr.at(510)) == 0x55 &&
                     static_cast<uchar>(mbr.at(511)) == 0xAA,
                 "Formatter omitted the MBR signature") &&
           check(hiddenSectors == 8192, "FAT32 hidden-sector field is incorrect") &&
           check(boot.mid(71, 11) == QByteArray("OPENHD     "),
                 "FAT32 volume label is incorrect") &&
           check(fsInfoLead == 0x41615252, "FAT32 FSInfo signature is incorrect") &&
           check(firstFatEntry == 0x0FFFFFF8, "FAT32 reserved entries are incorrect") &&
           check(boot == backupBoot, "FAT32 backup boot sector differs from primary") &&
           check(image.size() == imageSize, "Formatting changed the target size");
}

bool testRockchipFirmwareLayoutDiscovery()
{
    QTemporaryDir temporaryDirectory;
    const QString nestedFirmware = temporaryDirectory.filePath("bundle/output/firmware");
    if (!QDir().mkpath(nestedFirmware) ||
        !writeFile(QDir(nestedFirmware).filePath("parameter.txt"), "CMDLINE:mtdparts=rk29xxnand:0x20@0x40(boot)\n") ||
        !writeFile(QDir(nestedFirmware).filePath("boot.img"), QByteArray(512, '\0')))
        return check(false, "Could not create nested firmware fixture");

    QString detected;
    QString error;
    if (!check(findRockchipFirmwareDirectory(temporaryDirectory.path(), detected, &error),
               "ImageBuilder output/firmware layout was not detected") ||
        !check(QDir(detected).absolutePath() == QDir(nestedFirmware).absolutePath(),
               "Wrong nested firmware directory was selected"))
        return false;

    QTemporaryDir flatPackage;
    writeFile(flatPackage.filePath("parameter.txt"), "CMDLINE:mtdparts=rk29xxnand:0x20@0x40(boot)\n");
    writeFile(flatPackage.filePath("boot.img"), QByteArray(512, '\0'));
    if (!check(findRockchipFirmwareDirectory(flatPackage.path(), detected, &error),
               "Flat Rockchip package was no longer detected") ||
        !check(QDir(detected).absolutePath() == QDir(flatPackage.path()).absolutePath(),
               "Flat firmware root was not selected"))
        return false;

    QTemporaryDir incompletePackage;
    writeFile(incompletePackage.filePath("parameter.txt"), "partition table only");
    return check(!findRockchipFirmwareDirectory(incompletePackage.path(), detected, &error),
                 "A firmware directory without partition images was accepted");
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    int failures = 0;
    failures += testGroundSettingsAndCameraMapping() ? 0 : 1;
    failures += testImageNameRoleOverrides() ? 0 : 1;
    failures += testCustomizationInstall() ? 0 : 1;
    failures += testInvalidCertificateRejected() ? 0 : 1;
    failures += testStorageSelection() ? 0 : 1;
    failures += testPlatformFileOperations() ? 0 : 1;
    failures += testRingBufferFlowAndBackpressure() ? 0 : 1;
    failures += testBlockBatching() ? 0 : 1;
    failures += testWriteProgressWatchdog() ? 0 : 1;
    failures += testCurlRetryPolicy() ? 0 : 1;
    failures += testArchivePathValidation() ? 0 : 1;
    failures += testDriveSafetyPolicy() ? 0 : 1;
    failures += testDiskFormatter() ? 0 : 1;
    failures += testRockchipFirmwareLayoutDiscovery() ? 0 : 1;

    if (failures == 0)
        qInfo() << "All OpenHD backend characterization tests passed";
    return failures == 0 ? 0 : 1;
}
