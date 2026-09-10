/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "archivepathvalidator.h"

#include <QDir>
#include <QRegularExpression>

bool ArchivePathValidator::normalizeRelativePath(const QString &path,
                                                 QString &normalized,
                                                 QString *error)
{
    const auto reject = [&](const QString &message) {
        normalized.clear();
        if (error) *error = message;
        return false;
    };

    if (path.isEmpty() || path.size() > 4096 || path.contains(QChar('\0')))
        return reject(QStringLiteral("Archive entry has an invalid name"));

    QString portablePath = path;
    portablePath.replace('\\', '/');
    if (portablePath.startsWith('/') ||
        QRegularExpression(QStringLiteral("^[A-Za-z]:")).match(portablePath).hasMatch())
        return reject(QStringLiteral("Archive entry uses an absolute path"));

    const QStringList components = portablePath.split('/', Qt::KeepEmptyParts);
    for (const QString &component : components)
    {
        if (component == QStringLiteral(".."))
            return reject(QStringLiteral("Archive entry escapes the destination"));
    }

    normalized = QDir::cleanPath(portablePath);
    if (normalized.isEmpty() || normalized == QStringLiteral(".") ||
        normalized.startsWith(QStringLiteral("../")))
        return reject(QStringLiteral("Archive entry has an invalid relative path"));
    return true;
}
