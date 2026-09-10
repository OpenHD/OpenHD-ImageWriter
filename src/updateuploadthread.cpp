/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2024 OpenHD
 */

#include "updateuploadthread.h"

#include <QDebug>
#include <QCryptographicHash>
#include <QDir>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStorageInfo>
#include <QTimer>
#include <QUrl>

UpdateUploadThread::UpdateUploadThread(const QString &sourceFile, const QString &targetMountpoint,
                                       const QString &targetSubdirectory, const QString &destinationFileName,
                                       const QByteArray &expectedSha256, QObject *parent)
    : QThread(parent), _source(sourceFile), _mountpoint(targetMountpoint),
      _targetSubdirectory(targetSubdirectory), _destinationFileName(destinationFileName),
      _expectedSha256(expectedSha256.trimmed().toLower())
{
}

void UpdateUploadThread::run()
{
    QFileInfo sourceInfo(_source);
    const QUrl sourceUrl = QUrl::fromUserInput(_source);
    const bool isRemoteSource = sourceUrl.isValid() && sourceUrl.scheme().startsWith(QStringLiteral("http"), Qt::CaseInsensitive) && !sourceInfo.exists();

    qDebug() << "Starting update upload from" << _source << "to" << _mountpoint << "(remote:" << isRemoteSource << ")";

    emit status(tr("Checking update package..."));

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
    if (!_targetSubdirectory.isEmpty())
    {
        if (QDir::isAbsolutePath(_targetSubdirectory) || _targetSubdirectory.contains(QStringLiteral("..")) ||
            (!destinationDir.exists(_targetSubdirectory) && !destinationDir.mkpath(_targetSubdirectory)) ||
            !destinationDir.cd(_targetSubdirectory))
        {
            emit error(tr("Unable to access update destination folder."));
            return;
        }
    }

    QStorageInfo storageInfo(destinationDir);
    if (!storageInfo.isValid() || !storageInfo.isReady())
    {
        emit error(tr("Unable to query storage information for OpenHD partition."));
        return;
    }

    const auto destinationBytesFree = storageInfo.bytesAvailable();
    qint64 requiredBytes = -1;

    if (!isRemoteSource)
    {
        requiredBytes = sourceInfo.size();
    }

    qDebug() << "Destination free space:" << destinationBytesFree << "bytes" << "- required:" << requiredBytes;

    if (requiredBytes > 0 && destinationBytesFree < requiredBytes)
    {
        emit error(tr("Not enough space on the FAT partition (%1 MB available, %2 MB required).")
                       .arg(destinationBytesFree / (1024 * 1024))
                       .arg((requiredBytes + 1024 * 1024 - 1) / (1024 * 1024)));
        return;
    }

    QString destinationFileName = _destinationFileName;
    if (destinationFileName.isEmpty())
        destinationFileName = isRemoteSource ? sourceUrl.fileName() : sourceInfo.fileName();
    if (destinationFileName.isEmpty())
        destinationFileName = QStringLiteral("update.zip");
    if (QFileInfo(destinationFileName).fileName() != destinationFileName)
    {
        emit error(tr("Invalid update destination filename."));
        return;
    }
    const QString destinationPath = destinationDir.filePath(destinationFileName);
    QSaveFile destination(destinationPath);
    if (!destination.open(QIODevice::WriteOnly))
    {
        emit error(tr("Unable to write to OpenHD partition."));
        return;
    }

    emit status(tr("Preparing to copy update..."));

    QCryptographicHash packageHash(QCryptographicHash::Sha256);
    auto finalizeCopy = [this, &destination, &packageHash]() {
        const QByteArray actualSha256 = packageHash.result().toHex().toLower();
        if (!_expectedSha256.isEmpty() && actualSha256 != _expectedSha256)
        {
            emit error(tr("Update checksum verification failed."));
            return false;
        }
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

        auto createRequest = [&sourceUrl]() {
            QNetworkRequest request(sourceUrl);
            request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
            return request;
        };

        if (requiredBytes < 0)
        {
            QNetworkReply *headReply = manager.head(createRequest());
            QEventLoop headLoop;
            QTimer headTimeout;
            headTimeout.setSingleShot(true);
            headTimeout.setInterval(15000);
            QObject::connect(headReply, &QNetworkReply::finished, &headLoop, &QEventLoop::quit);
            QObject::connect(&headTimeout, &QTimer::timeout, &headLoop, &QEventLoop::quit);
            QObject::connect(&headTimeout, &QTimer::timeout, headReply, &QNetworkReply::abort);
            headTimeout.start();
            headLoop.exec();

            if (headReply->error() == QNetworkReply::NoError)
            {
                requiredBytes = headReply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
                if (requiredBytes <= 0)
                {
                    qDebug() << "HEAD request returned no usable size; will rely on GET";
                    requiredBytes = -1;
                }
                else
                {
                    qDebug() << "HEAD request determined remote update size:" << requiredBytes;
                }
            }
            else
            {
                qDebug() << "HEAD request failed with" << headReply->errorString();
            }
            headReply->deleteLater();

            if (headTimeout.isActive())
            {
                headTimeout.stop();
            }
            else if (requiredBytes <= 0)
            {
                emit error(tr("Update size check timed out."));
                return;
            }

            if (requiredBytes > 0 && destinationBytesFree < requiredBytes)
            {
                emit error(tr("Not enough space on the FAT partition (%1 MB available, %2 MB required).")
                               .arg(destinationBytesFree / (1024 * 1024))
                               .arg((requiredBytes + 1024 * 1024 - 1) / (1024 * 1024)));
                return;
            }
        }

        QNetworkReply *reply = manager.get(createRequest());
        QEventLoop loop;
        QTimer downloadTimeout;
        downloadTimeout.setSingleShot(true);
        downloadTimeout.setInterval(15000);
        qint64 downloadedBytes = 0;
        QElapsedTimer downloadTimer;
        downloadTimer.start();
        connect(reply, &QNetworkReply::downloadProgress, this, [this, &requiredBytes, &downloadTimeout](qint64 received, qint64 total) {
            downloadTimeout.start();
            if (requiredBytes <= 0 && total > 0)
            {
                requiredBytes = total;
                qDebug() << "GET content-length determined remote update size:" << requiredBytes;
            }
            if (total > 0)
                emit progress(static_cast<qreal>(received) / static_cast<qreal>(total));
            emit status(tr("Downloading update"));
        });
        connect(reply, &QNetworkReply::readyRead, &loop, [&]() {
            const QByteArray data = reply->readAll();
            if (data.isEmpty())
                return;

            if (requiredBytes > 0 && destinationBytesFree < downloadedBytes + data.size())
            {
                emit error(tr("Not enough space on the FAT partition (%1 MB available, %2 MB required).")
                               .arg(destinationBytesFree / (1024 * 1024))
                               .arg((requiredBytes + 1024 * 1024 - 1) / (1024 * 1024)));
                reply->abort();
                loop.quit();
                return;
            }

            if (destination.write(data) != data.size())
            {
                emit error(tr("Error writing update archive."));
                reply->abort();
                loop.quit();
                return;
            }

            packageHash.addData(data);
            downloadedBytes += data.size();
            if (requiredBytes > 0)
            {
                emit progress(static_cast<qreal>(downloadedBytes) / static_cast<qreal>(requiredBytes));
                emit status(tr("Downloading update (%1%)").arg(static_cast<int>((downloadedBytes * 100) / requiredBytes)));
            }

            const qint64 elapsedMs = downloadTimer.elapsed();
            const double bytesPerSecond = elapsedMs > 0 ? (downloadedBytes * 1000.0 / static_cast<double>(elapsedMs)) : 0.0;
            const QString totalText = requiredBytes > 0 ? QString::number(requiredBytes) : QStringLiteral("unknown");
            qDebug() << "Downloading update:" << downloadedBytes << "/" << totalText << "bytes" << "(" << bytesPerSecond << "bytes/s )";
        });
        connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        connect(&downloadTimeout, &QTimer::timeout, &loop, &QEventLoop::quit);
        connect(&downloadTimeout, &QTimer::timeout, reply, &QNetworkReply::abort);
        downloadTimeout.start();
        loop.exec();

        if (!downloadTimeout.isActive())
        {
            emit error(tr("Downloading update package timed out."));
            reply->deleteLater();
            return;
        }
        downloadTimeout.stop();

        if (reply->error() != QNetworkReply::NoError)
        {
            emit error(tr("Unable to download update package."));
            reply->deleteLater();
            return;
        }

        if (downloadedBytes <= 0)
        {
            emit error(tr("No data received while downloading update package."));
            reply->deleteLater();
            return;
        }

        qDebug() << "Downloaded" << downloadedBytes << "bytes";
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

        packageHash.addData(buffer.constData(), bytesRead);
        written += bytesRead;
        if (total > 0)
        {
            emit progress(static_cast<qreal>(written) / static_cast<qreal>(total));
            emit status(tr("Uploading update (%1%)").arg(static_cast<int>((written * 100) / total)));
        }
    }

    finalizeCopy();
}
