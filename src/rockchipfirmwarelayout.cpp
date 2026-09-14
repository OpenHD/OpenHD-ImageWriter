/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "rockchipfirmwarelayout.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QRegularExpression>

#include <limits>

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

QList<RockchipPartition> parseBlockDeviceParts(const QByteArray &environmentContent)
{
    QList<RockchipPartition> partitions;
    const QString text = QString::fromUtf8(environmentContent);
    const int marker = text.indexOf(QStringLiteral("blkdevparts="));
    if (marker == -1)
        return partitions;

    const int colon = text.indexOf(QLatin1Char(':'), marker);
    if (colon == -1)
        return partitions;

    QString definition = text.mid(colon + 1);
    const int lineEnd = definition.indexOf(QRegularExpression(QStringLiteral("[\\r\\n]")));
    if (lineEnd != -1)
        definition.truncate(lineEnd);

    auto bytesToSectors = [](const QString &value, quint64 &sectors) {
        QString number = value.trimmed();
        quint64 multiplier = 1;
        if (!number.isEmpty())
        {
            const QChar suffix = number.back().toUpper();
            if (suffix == QLatin1Char('K') || suffix == QLatin1Char('M') || suffix == QLatin1Char('G'))
            {
                multiplier = suffix == QLatin1Char('K') ? 1024ULL
                           : suffix == QLatin1Char('M') ? 1024ULL * 1024
                                                       : 1024ULL * 1024 * 1024;
                number.chop(1);
            }
        }

        bool ok = false;
        const quint64 numericValue = number.toULongLong(&ok, 0);
        if (!ok || numericValue > (std::numeric_limits<quint64>::max)() / multiplier)
            return false;
        const quint64 bytes = numericValue * multiplier;
        if ((bytes % 512) != 0)
            return false;
        sectors = bytes / 512;
        return true;
    };

    quint64 nextOffset = 0;
    const QStringList tokens = definition.split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (int tokenIndex = 0; tokenIndex < tokens.size(); ++tokenIndex)
    {
        const QString token = tokens.at(tokenIndex).trimmed();
        const int openParen = token.indexOf(QLatin1Char('('));
        const int closeParen = token.indexOf(QLatin1Char(')'), openParen + 1);
        if (openParen <= 0 || closeParen != token.size() - 1)
            return {};

        const QString name = token.mid(openParen + 1, closeParen - openParen - 1).trimmed();
        const QString sizeAndOffset = token.left(openParen).trimmed();
        if (name.isEmpty() || sizeAndOffset.isEmpty())
            return {};

        const int at = sizeAndOffset.indexOf(QLatin1Char('@'));
        const QString sizeText = at == -1 ? sizeAndOffset : sizeAndOffset.left(at).trimmed();
        if (at != -1)
        {
            quint64 explicitOffset = 0;
            if (!bytesToSectors(sizeAndOffset.mid(at + 1), explicitOffset))
                return {};
            nextOffset = explicitOffset;
        }

        quint64 size = 0;
        if (sizeText != QStringLiteral("-") && !bytesToSectors(sizeText, size))
            return {};
        if (nextOffset > (std::numeric_limits<quint32>::max)() ||
            size > (std::numeric_limits<quint32>::max)() ||
            (size != 0 && nextOffset + size > (std::numeric_limits<quint32>::max)()))
            return {};

        RockchipPartition partition;
        partition.name = name;
        partition.offset = static_cast<quint32>(nextOffset);
        partition.size = static_cast<quint32>(size);
        partitions.append(partition);

        if (size == 0)
        {
            if (tokenIndex != tokens.size() - 1)
                return {};
        }
        else
        {
            nextOffset += size;
        }
    }
    return partitions;
}

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
                          QStringList() << QStringLiteral("parameter.txt")
                                        << QStringLiteral(".env.txt"),
                          QDir::Files | QDir::Readable,
                          QDirIterator::Subdirectories);
    while (iterator.hasNext())
    {
        const QFileInfo metadata(iterator.next());
        const QString relativeDirectory = root.relativeFilePath(metadata.absolutePath());
        const QString normalized = QDir::fromNativeSeparators(relativeDirectory);
        if (!containsPartitionImage(metadata.absolutePath()))
            continue;

        const int score = layoutScore(normalized);
        if (score > bestScore)
        {
            bestScore = score;
            firmwareDirectory = metadata.absolutePath();
            ambiguous = false;
        }
        else if (score == bestScore &&
                 QDir(firmwareDirectory).absolutePath() != QDir(metadata.absolutePath()).absolutePath())
        {
            ambiguous = true;
        }
    }

    if (firmwareDirectory.isEmpty())
    {
        if (errorMessage)
            *errorMessage = QStringLiteral("The package does not contain Rockchip partition metadata together with partition images.");
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
