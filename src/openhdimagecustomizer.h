#ifndef OPENHDIMAGECUSTOMIZER_H
#define OPENHDIMAGECUSTOMIZER_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QJsonObject>
#include <QString>

class QSettings;

class OpenHDImageCustomizer final
{
public:
    enum class Error
    {
        None,
        CreateDirectory,
        WriteSettings,
        QOpenHDConfigNotFound,
        ReplaceQOpenHDConfig,
        CopyQOpenHDConfig,
        InvalidCertificate,
        ReplaceCertificate,
        CopyCertificate
    };

    struct Result
    {
        explicit Result(Error errorValue = Error::None,
                        const QString &detailValue = QString())
            : error(errorValue), detail(detailValue)
        {
        }

        Error error;
        QString detail;

        bool succeeded() const { return error == Error::None; }
    };

    static QJsonObject buildSettings(const QSettings &settings);
    static Result apply(const QString &bootPartition, const QSettings &settings);

private:
    OpenHDImageCustomizer() = delete;

    static QString cameraTypeForName(const QString &cameraName, const QString &sbc);
};

#endif // OPENHDIMAGECUSTOMIZER_H
