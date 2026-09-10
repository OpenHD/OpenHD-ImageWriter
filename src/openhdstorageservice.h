#ifndef OPENHDSTORAGESERVICE_H
#define OPENHDSTORAGESERVICE_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QString>
#include <QUrl>
#include <QVariantList>

/*
 * OpenHD-specific storage discovery and file operations.
 *
 * This service deliberately has no QML surface. ImageWriter keeps the existing
 * invokable API and delegates to this class, which lets the UI remain stable
 * while the backend is split into independently testable components.
 */
class OpenHDStorageService final
{
public:
    static QVariantList listTextFilesOnDevice(const QString &device);
    static QString readTextFile(const QString &filePath);
    static bool writeTextFile(const QString &filePath, const QString &content);
    static bool fileExists(const QString &filePath);
    static bool copyFile(const QString &sourcePath, const QString &destinationPath);
    static bool removeFile(const QString &filePath);

    static bool hasSettingsCard();
    static bool isOhdFile(const QUrl &url);
    static QString findFatPartition(const QString &device);

private:
    OpenHDStorageService() = delete; // Static service.
};

#endif // OPENHDSTORAGESERVICE_H
