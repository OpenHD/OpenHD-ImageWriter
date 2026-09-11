/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "rockchipfirmwarelayout.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>

namespace {

bool containsPartitionImage(const QString &directory)
{
    const QFileInfoList files = QDir(directory).entryInfoList(QDir::Files | QDir::Readable);
    for (const QFileInfo &file : files)
    {
        if (file.suffix().compare(QStringLiteral("img"), Qt::CaseInsensitive) == 0 &&
            file.size() > 0)
            return true;
    }
    return false;
}

int layoutScore(const QString &relativeDirectory)
{
    QString path = QDir::fromNativeSeparators(relativeDirectory).toLower();
    if (path == QStringLiteral("output/firmware"))
        return 500;
    if (path.endsWith(QStringLiteral("/output/firmware")))
        return 450;
    if (path == QStringLiteral("firmware"))
        return 400;
    if (path.endsWith(QStringLiteral("/firmware")))
        return 350;
    if (path == QStringLiteral("."))
        return 300;
    return 100;
}

} // namespace

bool findRockchipFirmwareDirectory(const QString &extractionRoot,
                                   QString &firmwareDirectory,
                                   QString *errorMessage)
{
    firmwareDirectory.clear();
    QDir root(extractionRoot);
    if (!root.exists())
    {
        if (errorMessage)
            *errorMessage = QStringLiteral("Firmware extraction directory does not exist.");
        return false;
    }

    int bestScore = -1;
    bool ambiguous = false;
    QDirIterator iterator(extractionRoot,
                          QStringList() << QStringLiteral("parameter.txt"),
                          QDir::Files | QDir::Readable,
                          QDirIterator::Subdirectories);
    while (iterator.hasNext())
    {
        const QFileInfo parameter(iterator.next());
        const QString relativeDirectory = root.relativeFilePath(parameter.absolutePath());
        const QString normalized = QDir::fromNativeSeparators(relativeDirectory);
        if (normalized.split(QLatin1Char('/'), Qt::SkipEmptyParts).size() > 8 ||
            !containsPartitionImage(parameter.absolutePath()))
            continue;

        const int score = layoutScore(normalized);
        if (score > bestScore)
        {
            bestScore = score;
            firmwareDirectory = parameter.absolutePath();
            ambiguous = false;
        }
        else if (score == bestScore &&
                 QDir(firmwareDirectory).absolutePath() != QDir(parameter.absolutePath()).absolutePath())
        {
            ambiguous = true;
        }
    }

    if (firmwareDirectory.isEmpty())
    {
        if (errorMessage)
            *errorMessage = QStringLiteral("The package does not contain parameter.txt together with partition images.");
        return false;
    }
    if (ambiguous)
    {
        firmwareDirectory.clear();
        if (errorMessage)
            *errorMessage = QStringLiteral("The package contains more than one possible firmware directory.");
        return false;
    }
    return true;
}
