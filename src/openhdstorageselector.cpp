#include "openhdstorageselector.h"

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QDir>
#include <QFileInfo>
#include <QStorageInfo>

int OpenHDStorageSelector::scoreMountPoint(const QString &mountPoint)
{
    const QDir mountDir(mountPoint);
    if (!mountDir.exists())
        return -1;

    int score = 10;
    const QStorageInfo storage(mountDir);
    if (storage.isValid() && storage.isReady() && !storage.isReadOnly())
    {
        const QString fsType = QString::fromLatin1(storage.fileSystemType()).toLower();
        if (fsType.contains("fat") || fsType.contains("msdos") || fsType.contains("vfat"))
            score += 50;
    }

    if (QFileInfo::exists(mountDir.filePath("openhd/settings.json")) ||
        QFileInfo::exists(mountDir.filePath("settings.json")))
    {
        score += 40;
    }
    else if (QFileInfo::exists(mountDir.filePath("openhd")))
    {
        score += 30;
    }

    if (QFileInfo::exists(mountDir.filePath("config.txt")))
        score += 35;
    if (!mountDir.entryList(QStringList() << "*.ohd", QDir::Files).isEmpty())
        score += 40;

    return score;
}

QString OpenHDStorageSelector::selectBestMountPoint(const QStringList &mountPoints)
{
    QString bestMountPoint;
    int bestScore = -1;

    for (QString mountPoint : mountPoints)
    {
#ifdef Q_OS_WIN
        if (mountPoint.length() == 2 && mountPoint.endsWith(':'))
            mountPoint += QLatin1Char('/');
#endif
        if (mountPoint.length() > 3 && (mountPoint.endsWith('/') || mountPoint.endsWith('\\')))
            mountPoint.chop(1);

        const int score = scoreMountPoint(mountPoint);
        if (score > bestScore)
        {
            bestScore = score;
            bestMountPoint = mountPoint;
        }
    }

    return bestMountPoint;
}
