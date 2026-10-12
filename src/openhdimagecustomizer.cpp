#include "openhdimagecustomizer.h"

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "certificatevalidator.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QSettings>
#include <QSaveFile>
#include <QRegularExpression>
#include <QUrl>
#include <QtGlobal>

QString OpenHDImageCustomizer::cameraTypeForName(const QString &cameraName, const QString &sbc)
{
    QFile file(":/doc/openhd_settings_map.json");
    if (!file.open(QIODevice::ReadOnly)) return {};
    const auto camera=QJsonDocument::fromJson(file.readAll()).object().value("camera").toObject();
    const auto search=[&](const QJsonArray& vendors) -> QString {
        for (const auto& vendor:vendors) for (const auto& option:vendor.toObject().value("options").toArray()) {
            const auto object=option.toObject();
            if (object.value("id").toString()==cameraName) return object.value("valueWritten").toVariant().toString();
        }
        return {};
    };
    for (const auto& group:camera.value("sbcGroups").toArray()) {
        const auto object=group.toObject();
        if (object.value("sbc").toArray().contains(sbc)) {
            const auto result=search(object.value("vendors").toArray());
            if (!result.isEmpty()) return result;
        }
    }
    return search(camera.value("commonVendors").toArray());

}

QJsonObject OpenHDImageCustomizer::buildSettings(const QSettings &settings)
{
    const QString cameraName = settings.value("camera").toString();
    const QString camera2Name = settings.value("camera2").toString();
    const QString cameraResolution = settings.value("cameraResolution").toString().trimmed();
    const QString camera2Resolution = settings.value("camera2Resolution").toString().trimmed();
    const QString cameraPort = settings.value("cameraPort", "cam1").toString() == "cam0" ? "cam0" : "cam1";
    const QString camera2Port = settings.value("camera2Port", "cam0").toString() == "cam1" ? "cam1" : "cam0";
    const QString defaultIpCameraPipeline = QStringLiteral(
        "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay");
    const QString ipCameraAddress = settings.value("ipCameraAddress", "192.168.144.108").toString().trimmed();
    const QString ipCameraPipeline = settings.value("ipCameraPipeline", defaultIpCameraPipeline).toString().trimmed();
    const QString camera2IpCameraAddress = settings.value("camera2IpCameraAddress", "192.168.144.108").toString().trimmed();
    const QString camera2IpCameraPipeline = settings.value("camera2IpCameraPipeline", defaultIpCameraPipeline).toString().trimmed();
    const int ipCameraBitrate = qBound(1, settings.value("ipCameraBitrate", 2).toInt(), 20);
    const bool displayForceMode = settings.value("displayForceMode", false).toBool();
    const int displayWidth = qBound(320, settings.value("displayWidth", 1920).toInt(), 7680);
    const int displayHeight = qBound(240, settings.value("displayHeight", 1080).toInt(), 4320);
    const int displayRefreshHz = qBound(20, settings.value("displayRefreshHz", 60).toInt(), 240);
    const bool disableEthernetLink = settings.value("disableEthernetLink", true).toBool();
    const QString mapboxApiKey = settings.value("mapboxApiKey").toString().trimmed();
    const bool fleetControlSignedIn = settings.value("fleetcontrol_signed_in", false).toBool();
    const QString fleetControlUsername = settings.value("fleetcontrol_username").toString().trimmed();
    const QString fleetControlPassword = settings.value("fleetcontrol_password").toString();
    const QString sbc = settings.value("sbc").toString();
    const QString mode = settings.value("mode").toString();
    QString bootType = settings.value("bootType").toString();
    const QString imageFileName = settings.value("fileName").toString().toLower();

    if (imageFileName.contains("x20"))
        bootType = "Air";
    else if (imageFileName.contains("lite") || imageFileName.contains("minimal"))
        bootType = "Ground";

    QJsonObject openhdSettings;
    const QString cameraType = cameraTypeForName(cameraName, sbc);
    if (!cameraName.isEmpty() && !cameraType.isEmpty())
        openhdSettings.insert("camera", cameraType);

    QString camera2Type = cameraTypeForName(camera2Name, sbc);
    if (camera2Type.isEmpty())
        camera2Type = "255";
    openhdSettings.insert("camera2", camera2Type);

    if (!cameraName.isEmpty() && !cameraResolution.isEmpty())
        openhdSettings.insert("camera_resolution_fps", cameraResolution);
    if (camera2Type != "255" && !camera2Resolution.isEmpty())
        openhdSettings.insert("camera2_resolution_fps", camera2Resolution);

    const auto isRpiCsiCameraType = [](const QString &value) {
        bool ok = false;
        const int cameraTypeValue = value.toInt(&ok);
        return ok && cameraTypeValue >= 20 && cameraTypeValue <= 69;
    };
    if (sbc == "rpi" && isRpiCsiCameraType(cameraType))
        openhdSettings.insert("camera_port", cameraPort);
    if (sbc == "rpi" && isRpiCsiCameraType(camera2Type))
        openhdSettings.insert("camera2_port", camera2Port);

    if (cameraType == "3")
    {
        openhdSettings.insert("ip_camera_address", ipCameraAddress);
        openhdSettings.insert("ip_camera_pipeline", ipCameraPipeline);
    }
    if (camera2Type == "3")
    {
        openhdSettings.insert("camera2_ip_camera_address", camera2IpCameraAddress);
        openhdSettings.insert("camera2_ip_camera_pipeline", camera2IpCameraPipeline);
    }
    if (cameraType == "3" || camera2Type == "3")
        openhdSettings.insert("ip_camera_bitrate_mbits", ipCameraBitrate);

    if (!sbc.isEmpty())
        openhdSettings.insert("sbc", sbc);
    if (!settings.value("platform").toString().isEmpty())
        openhdSettings.insert("platform", settings.value("platform").toString());
    if (mode == "debug")
        openhdSettings.insert("debug", true);
    openhdSettings.insert("disable_ethernet_link", disableEthernetLink);

    if (bootType == "Air")
    {
        openhdSettings.insert("role", "air");
    }
    else if (bootType == "Ground")
    {
        openhdSettings.insert("role", "ground");
        openhdSettings.insert("display_force_mode", displayForceMode);
        if (displayForceMode)
        {
            openhdSettings.insert("display_width", displayWidth);
            openhdSettings.insert("display_height", displayHeight);
            openhdSettings.insert("display_refresh_hz", displayRefreshHz);
            openhdSettings.insert("display_connector", "HDMI-A-1");
        }
    }

    openhdSettings.insert("language", settings.value("language").toString());
    openhdSettings.insert("token", settings.value("token").toString());
    if (!mapboxApiKey.isEmpty())
        openhdSettings.insert("mapbox_api_key", mapboxApiKey);
    if (fleetControlSignedIn && !fleetControlUsername.isEmpty() && !fleetControlPassword.isEmpty())
    {
        openhdSettings.insert("fleetcontrol_username", fleetControlUsername);
        openhdSettings.insert("fleetcontrol_password", fleetControlPassword);
    }
    const auto defaults=QJsonDocument::fromJson(settings.value("initialParameterDefaults").toString().toUtf8()).object();
    if (defaults.value("version").toInt()==1 && defaults.value("components").isObject())
        openhdSettings.insert("parameter_defaults",defaults);
    return openhdSettings;
}

QJsonObject OpenHDImageCustomizer::initialConfiguration(const QSettings &settings)
{
    auto file = buildSettings(settings);
    for (const auto &key : {"fleetcontrol_username", "fleetcontrol_password", "token"}) file.remove(key);
    QJsonObject selections;
    for (const auto &key : {"bootType", "platform", "sbc", "camera", "camera2", "cameraResolution", "camera2Resolution",
         "cameraPort", "camera2Port", "ipCameraAddress", "ipCameraPipeline", "camera2IpCameraAddress", "camera2IpCameraPipeline",
         "ipCameraBitrate", "displayForceMode", "displayWidth", "displayHeight", "displayRefreshHz", "mode", "hotSpot",
         "useSettings", "mapboxApiKey", "disableEthernetLink", "initialParameterDefaults", "language"})
        if (settings.contains(key)) selections.insert(key, QJsonValue::fromVariant(settings.value(key)));
    selections.insert("mode", file.value("role"));
    selections.insert("bootType", file.value("role").toString() == "ground" ? "Ground" : "Air");
    selections.insert("debug", file.value("debug").toBool());
    return {{"version", 1}, {"settings", file}, {"imageWriterSettings", selections}};
}

OpenHDImageCustomizer::Result OpenHDImageCustomizer::prepareBootSplash(const QString &bootPartition)
{
    const QDir boot(bootPartition);
    QFile capability(boot.filePath("openhd-boot-splash.version"));
    if (!capability.exists())
        return Result(); // Older images and other platforms do not contain the runtime support.
    if (!capability.open(QIODevice::ReadOnly))
        return Result(Error::WriteBootConfiguration);
    if (capability.readAll().trimmed() != "1")
        return Result(); // Leave future image formats to their matching writer.

    QFile cmdline(boot.filePath("cmdline.txt"));
    QFile config(boot.filePath("config.txt"));
    if (!cmdline.open(QIODevice::ReadOnly) || !config.open(QIODevice::ReadOnly))
        return Result(Error::WriteBootConfiguration);
    const QString originalCmdline = QString::fromUtf8(cmdline.readAll());
    const QString originalConfig = QString::fromUtf8(config.readAll());
    cmdline.close();
    config.close();

    const QStringList required = {"quiet", "splash", "logo.nologo", "plymouth.ignore-serial-consoles",
                                  "console=tty3", "loglevel=3", "systemd.show_status=false",
                                  "vt.global_cursor_default=0"};
    QStringList tokens;
    for (const QString &token : originalCmdline.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts))
    {
        if (token == "console=tty1" || token == "console=tty3" || required.contains(token) ||
            token.startsWith("loglevel=") || token.startsWith("systemd.show_status=") ||
            token.startsWith("vt.global_cursor_default="))
            continue;
        tokens.append(token);
    }
    tokens.append(required);
    const QByteArray newCmdline = (tokens.join(' ') + '\n').toUtf8();

    QStringList lines;
    const QRegularExpression disableSplash("^\\s*disable_splash\\s*=");
    QString configWithoutBlock = originalConfig;
    configWithoutBlock.remove("[all]\n# OpenHD boot splash\ndisable_splash=1\n");
    for (const QString &line : configWithoutBlock.split('\n'))
    {
        if (disableSplash.match(line).hasMatch() || line.trimmed() == "# OpenHD boot splash")
            continue;
        lines.append(line);
    }
    QString newConfig = lines.join('\n');
    const QString block = "[all]\n# OpenHD boot splash\ndisable_splash=1\n";
    const int dynamicStart = newConfig.indexOf("#OPENHD_DYNAMIC_CONTENT_BEGIN#");
    if (dynamicStart >= 0)
        newConfig.insert(dynamicStart, block);
    else
        newConfig += (newConfig.endsWith('\n') ? "" : "\n") + block;

    const auto save = [](const QString &path, const QByteArray &contents) {
        QSaveFile file(path);
        return file.open(QIODevice::WriteOnly) && file.write(contents) == contents.size() && file.commit();
    };
    if (!save(boot.filePath("cmdline.txt"), newCmdline) ||
        !save(boot.filePath("config.txt"), newConfig.toUtf8()))
        return Result(Error::WriteBootConfiguration);
    return Result();
}

OpenHDImageCustomizer::Result OpenHDImageCustomizer::apply(const QString &bootPartition,
                                                            const QSettings &settings)
{
    const Result bootResult = prepareBootSplash(bootPartition);
    if (!bootResult.succeeded()) return bootResult;

    QDir openhdDir(QDir(bootPartition).filePath("openhd"));
    if (!openhdDir.exists() && !openhdDir.mkpath("."))
        return Result(Error::CreateDirectory);

    QFile settingsFile(openhdDir.filePath("settings.json"));
    if (!settingsFile.open(QIODevice::WriteOnly))
        return Result(Error::WriteSettings);

    const QByteArray settingsJson = QJsonDocument(buildSettings(settings)).toJson();
    if (settingsFile.write(settingsJson) != settingsJson.size())
        return Result(Error::WriteSettings);
    settingsFile.close();

    QString qopenhdConfigPath = settings.value("qopenhdConfPath").toString();
    if (qopenhdConfigPath.startsWith("file:"))
        qopenhdConfigPath = QUrl(qopenhdConfigPath).toLocalFile();

    if (!qopenhdConfigPath.isEmpty())
    {
        const QFileInfo configInfo(qopenhdConfigPath);
        if (!configInfo.exists() || !configInfo.isFile())
            return Result(Error::QOpenHDConfigNotFound);

        const QString targetConfigPath = openhdDir.filePath("QOpenHD.conf");
        if (QFileInfo::exists(targetConfigPath) && !QFile::remove(targetConfigPath))
            return Result(Error::ReplaceQOpenHDConfig);
        if (!QFile::copy(qopenhdConfigPath, targetConfigPath))
            return Result(Error::CopyQOpenHDConfig);
    }

    QString offlineMapPath = settings.value("offlineMapPackagePath").toString();
    if (offlineMapPath.startsWith("file:"))
        offlineMapPath = QUrl(offlineMapPath).toLocalFile();
    if (!offlineMapPath.isEmpty() && settings.value("bootType").toString() == "Ground")
    {
        const QFileInfo mapInfo(offlineMapPath);
        if (!mapInfo.isFile())
            return Result(Error::OfflineMapNotFound);
        QFile mapFile(offlineMapPath);
        if (!mapFile.open(QIODevice::ReadOnly) || mapFile.read(8) != QByteArray("GLDMAP1\0", 8))
            return Result(Error::InvalidOfflineMap);
        QDir mapDir(openhdDir.filePath("maps"));
        if (!mapDir.exists() && !mapDir.mkpath("."))
            return Result(Error::CopyOfflineMap);
        const QString target = mapDir.filePath(mapInfo.fileName());
        if (QFileInfo::exists(target) && !QFile::remove(target))
            return Result(Error::CopyOfflineMap);
        if (!QFile::copy(offlineMapPath, target))
            return Result(Error::CopyOfflineMap);
    }

    QString certificatePath = settings.value("premiumCertificatePath").toString();
    if (certificatePath.startsWith("file:"))
        certificatePath = QUrl(certificatePath).toLocalFile();

    if (!certificatePath.isEmpty())
    {
        const QString certificateError =
            CertificateValidator::validatePremiumCertificateFile(certificatePath);
        if (!certificateError.isEmpty())
            return Result(Error::InvalidCertificate, certificateError);

        const QString targetCertificatePath = openhdDir.filePath("premium_certificate.ohdcert");
        if (QFileInfo::exists(targetCertificatePath) && !QFile::remove(targetCertificatePath))
            return Result(Error::ReplaceCertificate);
        if (!QFile::copy(certificatePath, targetCertificatePath))
            return Result(Error::CopyCertificate);
    }

    return Result();
}
