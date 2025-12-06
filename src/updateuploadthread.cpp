/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2024 OpenHD
 */

#include "updateuploadthread.h"

#include <QDir>
#include <QFile>
#include <QEventLoop>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QUrl>

UpdateUploadThread::UpdateUploadThread(const QString &sourceFile, const QString &targetMountpoint, QObject *parent)
    : QThread(parent), _source(sourceFile), _mountpoint(targetMountpoint)
{
}

void UpdateUploadThread::run()
{
    QFileInfo sourceInfo(_source);
    const QUrl sourceUrl = QUrl::fromUserInput(_source);
    const bool isRemoteSource = sourceUrl.isValid() && sourceUrl.scheme().startsWith(QStringLiteral("http"), Qt::CaseInsensitive) && !sourceInfo.exists();

    if (!isRemoteSource && (!sourceInfo.exists() || !sourceInfo.isFile()))
    {
        emit error(tr("Update file is not available."));
        return;
    }

    if (!QFileInfo::exists(_mountpoint) || !QFileInfo(_mountpoint).isDir())
    {
        emit error(tr("OpenHD storage is not mounted."));
        return;
    }

    QDir destinationDir(_mountpoint);
    if (!destinationDir.exists("openhd") && !destinationDir.mkpath("openhd"))
    {
        emit error(tr("Unable to access OpenHD settings folder."));
        return;
    }
    destinationDir.cd("openhd");

    const QString destinationFileName = sourceInfo.fileName().isEmpty() ? QStringLiteral("update.zip") : sourceInfo.fileName();
    const QString destinationPath = destinationDir.filePath(destinationFileName);
    QSaveFile destination(destinationPath);
    if (!destination.open(QIODevice::WriteOnly))
    {
        emit error(tr("Unable to write to OpenHD partition."));
        return;
    }

    auto finalizeCopy = [this, &destination]() {
        if (!destination.commit())
        {
            emit error(tr("Unable to finalize upload."));
            return false;
        }

        emit progress(1.0);
        emit success();
        return true;
    };

    if (isRemoteSource)
    {
        QNetworkAccessManager manager;
        QNetworkRequest requestObj(sourceUrl);
        QNetworkReply *reply = manager.get(requestObj);
        QEventLoop loop;
        connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 received, qint64 total) {
            if (total > 0)
                emit progress(static_cast<qreal>(received) / static_cast<qreal>(total));
            emit status(tr("Downloading update"));
        });
        connect(reply, &QNetworkReply::readyRead, &loop, [&]() {
            const QByteArray data = reply->readAll();
            if (data.isEmpty())
                return;
            if (destination.write(data) != data.size())
            {
                emit error(tr("Error writing update archive."));
                reply->abort();
                loop.quit();
            }
        });
        connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        loop.exec();

        if (reply->error() != QNetworkReply::NoError)
        {
            emit error(tr("Unable to download update package."));
            reply->deleteLater();
            return;
        }
        reply->deleteLater();
        finalizeCopy();
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

    finalizeCopy();
}
