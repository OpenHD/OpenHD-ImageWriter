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
#include <QSettings>
#include <QUrl>
#include <QtGlobal>

QString OpenHDImageCustomizer::cameraTypeForName(const QString &cameraName, const QString &sbc)
{
    if (cameraName.isEmpty())
        return QString();

    qDebug() << "Camera found" << cameraName;

    QString cameraType;
    if (sbc == "rpi")
    {
        if (cameraName == "OV5647") cameraType = "30";
        else if (cameraName == "IMX219") cameraType = "31";
        else if (cameraName == "IMX708") cameraType = "32";
        else if (cameraName == "IMX477") cameraType = "33";
        else if (cameraName == "HDMI") cameraType = "20";
        else if (cameraName == "SkyMasterHDR708") cameraType = "40";
        else if (cameraName == "SkyVisionPro519") cameraType = "41";
        else if (cameraName == "IMX477m") cameraType = "42";
        else if (cameraName == "IMX462") cameraType = "43";
        else if (cameraName == "IMX327") cameraType = "44";
        else if (cameraName == "IMX290") cameraType = "45";
        else if (cameraName == "IMX462MINI") cameraType = "46";
        else if (cameraName == "IMX662") cameraType = "47";
        else if (cameraName == "2MPCAMERAS") cameraType = "60";
        else if (cameraName == "CSIMX307") cameraType = "61";
        else if (cameraName == "CSSC137") cameraType = "62";
        else if (cameraName == "MVCAM") cameraType = "63";
    }
    else if (sbc == "zero3w")
    {
        if (cameraName == "HDMI") cameraType = "90";
        else if (cameraName == "IMX462") cameraType = "94";
        else if (cameraName == "IMX519") cameraType = "95";
        else if (cameraName == "IMX219") cameraType = "92";
        else if (cameraName == "OV5647") cameraType = "91";
        else if (cameraName == "IMX708") cameraType = "93";
        else if (cameraName == "VEYE") cameraType = "97";
        else if (cameraName == "OHD-JAGUAR") cameraType = "96";
    }
    else if (sbc == "rock-5b" || sbc == "rock-5a" || sbc == "radxa-cm5")
    {
        if (cameraName == "HDMI") cameraType = "80";
        else if (cameraName == "IMX219") cameraType = "82";
        else if (cameraName == "OV5647") cameraType = "81";
        else if (cameraName == "IMX708") cameraType = "83";
        else if (cameraName == "IMX462") cameraType = "84";
        else if (cameraName == "IMX415") cameraType = "85";
        else if (cameraName == "IMX477") cameraType = "86";
        else if (cameraName == "IMX519") cameraType = "87";
        else if (cameraName == "OHD-JAGUAR") cameraType = "88";
    }

    if (cameraName == "FILESRC") cameraType = "4";
    else if (cameraName == "IP-CAMERA") cameraType = "3";
    else if (cameraName == "EXTERNAL") cameraType = "2";
    else if (cameraName == "USB") cameraType = "10";
    else if (cameraName == "TESTPATTERN") cameraType = "0";
    else if (cameraName == "INFIRAY") cameraType = "11";
    else if (cameraName == "INFIRAY_T2") cameraType = "12";
    else if (cameraName == "INFIRAY_X2") cameraType = "13";
    else if (cameraName == "INFIRAY_P2_PRO") cameraType = "14";
    else if (cameraName == "FLIR_VUE" || cameraName == "FLIR VUE") cameraType = "15";
    else if (cameraName == "FLIR_BOSON" || cameraName == "FLIR BOSON") cameraType = "16";
    else if (cameraName == "HDZERO") cameraType = "70";
    else if (cameraName == "RUNCAM_V1") cameraType = "71";
    else if (cameraName == "RUNCAM_V2") cameraType = "72";
    else if (cameraName == "RUNCAM_V3") cameraType = "73";
    else if (cameraName == "RUNCAM_NANO_90") cameraType = "74";
    else if (cameraName == "OHD-JAGUAR-X21") cameraType = "76";
    else if (cameraName == "OPENIPC") cameraType = "110";
    else if (cameraName == "XAVIER-IMX577") cameraType = "101";
    else if (cameraName == "ORQA-HORNET") cameraType = "122";
    else if (cameraName == "ORQA-JAGUAR") cameraType = "123";
    else if (cameraName == "ORQA-REKINDLE") cameraType = "124";
    else if (cameraName == "ROCKCHIP-RV") cameraType = "125";
    else if (sbc == "x20" && cameraName == "OHD-JAGUAR") cameraType = "75";
    else if ((sbc == "qcs405" || sbc == "qrb5165") && cameraName == "IMX577") cameraType = "120";
    else if ((sbc == "qcs405" || sbc == "qrb5165") && cameraName == "OV9282") cameraType = "121";

    return cameraType;
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
    if (mode == "debug")
        openhdSettings.insert("debug", true);

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
    return openhdSettings;
}

OpenHDImageCustomizer::Result OpenHDImageCustomizer::apply(const QString &bootPartition,
                                                            const QSettings &settings)
{
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
