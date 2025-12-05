/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2024 OpenHD
 */

#include "updateuploadthread.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>

UpdateUploadThread::UpdateUploadThread(const QString &sourceFile, const QString &targetMountpoint, QObject *parent)
    : QThread(parent), _source(sourceFile), _mountpoint(targetMountpoint)
{
}

void UpdateUploadThread::run()
{
    QFileInfo sourceInfo(_source);
    if (!sourceInfo.exists() || !sourceInfo.isFile())
    {
        emit error(tr("Update file is not available."));
        return;
    }

    if (!QFileInfo::exists(_mountpoint) || !QFileInfo(_mountpoint).isDir())
    {
        emit error(tr("OpenHD storage is not mounted."));
        return;
    }

    QFile sourceFile(_source);
    if (!sourceFile.open(QIODevice::ReadOnly))
    {
        emit error(tr("Unable to read update archive."));
        return;
    }

    const qint64 total = sourceFile.size();
    emit status(tr("Uploading update"));

    QDir destinationDir(_mountpoint);
    const QString destinationPath = destinationDir.filePath("upload.zip");
    QSaveFile destination(destinationPath);
    if (!destination.open(QIODevice::WriteOnly))
    {
        emit error(tr("Unable to write to OpenHD partition."));
        return;
    }

    QByteArray buffer;
    buffer.resize(512 * 1024);
    qint64 written = 0;

    while (!sourceFile.atEnd())
    {
        const qint64 bytesRead = sourceFile.read(buffer.data(), buffer.size());
        if (bytesRead <= 0)
        {
            emit error(tr("Error reading update archive."));
            return;
        }

        if (destination.write(buffer.constData(), bytesRead) != bytesRead)
        {
            emit error(tr("Error writing update archive."));
            return;
        }

        written += bytesRead;
        if (total > 0)
        {
            emit progress(static_cast<qreal>(written) / static_cast<qreal>(total));
            emit status(tr("Uploading update (%1%)").arg(static_cast<int>((written * 100) / total)));
        }
    }

    if (!destination.commit())
    {
        emit error(tr("Unable to finalize upload."));
        return;
    }

    emit progress(1.0);
    emit success();
}
