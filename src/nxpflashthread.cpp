/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "nxpflashthread.h"
#include "archivepathvalidator.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <archive.h>
#include <archive_entry.h>

NxpFlashThread::NxpFlashThread(const QUrl &source, QObject *parent)
    : QThread(parent), _source(source)
{
}

NxpFlashThread::~NxpFlashThread()
{
    cancel();
    wait();
}

void NxpFlashThread::cancel()
{
    _cancelled = true;
}

QString NxpFlashThread::findUuuExecutable()
{
    const QString applicationDirectory = QCoreApplication::applicationDirPath();
    QStringList candidates;
#ifdef Q_OS_WIN
    candidates << QDir(applicationDirectory).filePath(QStringLiteral("uuu/uuu.exe"))
               << QDir(applicationDirectory).filePath(QStringLiteral("uuu.exe"));
#else
    candidates << QDir(applicationDirectory).filePath(QStringLiteral("uuu/uuu"))
               << QDir(applicationDirectory).filePath(QStringLiteral("uuu"));
#endif
    const QString fromPath = QStandardPaths::findExecutable(QStringLiteral("uuu"));
    if (!fromPath.isEmpty())
        candidates << fromPath;

    for (const QString &candidate : candidates)
    {
        const QFileInfo info(candidate);
        if (info.exists() && info.isFile() && info.isExecutable())
            return info.absoluteFilePath();
    }
    return QString();
}

bool NxpFlashThread::extractArchive(const QString &archivePath, const QString &destination,
                                    QString *errorMessage)
{
    constexpr int MaxEntries = 8192;
    constexpr quint64 MaxExtractedBytes = 128ULL * 1024 * 1024 * 1024;
    struct archive *reader = archive_read_new();
    archive_read_support_format_all(reader);
    archive_read_support_filter_all(reader);
    if (archive_read_open_filename(reader, archivePath.toLocal8Bit().constData(), 65536) != ARCHIVE_OK)
    {
        if (errorMessage) *errorMessage = QString::fromUtf8(archive_error_string(reader));
        archive_read_free(reader);
        return false;
    }

    struct archive_entry *entry = nullptr;
    QSet<QString> extractedPaths;
    int count = 0;
    quint64 extractedBytes = 0;
    int result = ARCHIVE_OK;
    while ((result = archive_read_next_header(reader, &entry)) == ARCHIVE_OK)
    {
        if (_cancelled)
            break;
        if (++count > MaxEntries)
        {
            if (errorMessage) *errorMessage = tr("Firmware archive contains too many entries.");
            result = ARCHIVE_FATAL;
            break;
        }

        const char *rawPath = archive_entry_pathname_utf8(entry);
        if (!rawPath) rawPath = archive_entry_pathname(entry);
        QString relativePath;
        QString pathError;
        const auto type = archive_entry_filetype(entry);
        if (!rawPath || !ArchivePathValidator::normalizeRelativePath(
                    QString::fromUtf8(rawPath), relativePath, &pathError) ||
            (type != AE_IFDIR && type != AE_IFREG) ||
            archive_entry_symlink(entry) || archive_entry_hardlink(entry))
        {
            if (errorMessage) *errorMessage = pathError.isEmpty()
                    ? tr("Firmware archive contains a link or unsupported special file.") : pathError;
            result = ARCHIVE_FATAL;
            break;
        }
        const QString pathKey = relativePath.toLower();
        if (extractedPaths.contains(pathKey))
        {
            if (errorMessage) *errorMessage = tr("Firmware archive contains duplicate paths.");
            result = ARCHIVE_FATAL;
            break;
        }
        extractedPaths.insert(pathKey);

        const QString outputPath = QDir(destination).filePath(relativePath);
        if (type == AE_IFDIR)
        {
            if (!QDir().mkpath(outputPath))
            {
                if (errorMessage) *errorMessage = tr("Unable to create a firmware package directory.");
                result = ARCHIVE_FATAL;
                break;
            }
            continue;
        }
        if (!QDir().mkpath(QFileInfo(outputPath).path()))
        {
            if (errorMessage) *errorMessage = tr("Unable to create a firmware package directory.");
            result = ARCHIVE_FATAL;
            break;
        }
        QFile output(outputPath);
        if (!output.open(QIODevice::WriteOnly))
        {
            if (errorMessage) *errorMessage = tr("Unable to extract %1.").arg(relativePath);
            result = ARCHIVE_FATAL;
            break;
        }
        char buffer[65536];
        la_ssize_t bytesRead = 0;
        while ((bytesRead = archive_read_data(reader, buffer, sizeof(buffer))) > 0)
        {
            extractedBytes += static_cast<quint64>(bytesRead);
            if (_cancelled || extractedBytes > MaxExtractedBytes || output.write(buffer, bytesRead) != bytesRead)
            {
                if (errorMessage && !_cancelled)
                    *errorMessage = extractedBytes > MaxExtractedBytes
                            ? tr("Firmware archive is too large.")
                            : tr("Unable to write extracted firmware data.");
                result = ARCHIVE_FATAL;
                break;
            }
        }
        output.close();
        if (result == ARCHIVE_FATAL || bytesRead < 0)
        {
            if (bytesRead < 0 && errorMessage)
                *errorMessage = QString::fromUtf8(archive_error_string(reader));
            result = ARCHIVE_FATAL;
            break;
        }
    }

    const bool ok = !_cancelled && result == ARCHIVE_EOF;
    if (!ok && result != ARCHIVE_FATAL && errorMessage && errorMessage->isEmpty())
        *errorMessage = QString::fromUtf8(archive_error_string(reader));
    archive_read_close(reader);
    archive_read_free(reader);
    return ok;
}

void NxpFlashThread::run()
{
    QTemporaryDir temporaryDirectory;
    if (!temporaryDirectory.isValid())
    {
        emit error(tr("Failed to create temporary working directory."));
        return;
    }

    QString packagePath;
    if (_source.isLocalFile())
        packagePath = _source.toLocalFile();
    else
    {
        emit preparationStatusUpdate(tr("Downloading NXP firmware package..."));
        QNetworkAccessManager manager;
        QNetworkRequest request(_source);
        request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
        QNetworkReply *reply = manager.get(request);
        QEventLoop loop;
        connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        connect(reply, &QNetworkReply::downloadProgress, this,
                [this](qint64 received, qint64 total) {
            if (!_cancelled && total > 0)
                emit writeProgress(received, total);
        });
        loop.exec();
        if (_cancelled)
        {
            reply->abort();
            reply->deleteLater();
            return;
        }
        if (reply->error() != QNetworkReply::NoError)
        {
            emit error(tr("Failed to download firmware: %1").arg(reply->errorString()));
            reply->deleteLater();
            return;
        }
        packagePath = temporaryDirectory.filePath(QStringLiteral("nxp-firmware-package"));
        QFile output(packagePath);
        if (!output.open(QIODevice::WriteOnly) || output.write(reply->readAll()) < 0)
        {
            emit error(tr("Failed to save downloaded firmware."));
            reply->deleteLater();
            return;
        }
        output.close();
        reply->deleteLater();
    }

    const QString extractionDirectory = temporaryDirectory.filePath(QStringLiteral("firmware"));
    if (!QDir().mkpath(extractionDirectory))
    {
        emit error(tr("Unable to create the firmware extraction directory."));
        return;
    }
    emit preparationStatusUpdate(tr("Extracting NXP firmware package..."));
    QString extractionError;
    if (!extractArchive(packagePath, extractionDirectory, &extractionError))
    {
        if (!_cancelled)
            emit error(tr("Failed to extract NXP firmware archive: %1").arg(extractionError));
        return;
    }

    QStringList scripts;
    QDirIterator iterator(extractionDirectory, QStringList() << QStringLiteral("uuu.auto"),
                          QDir::Files | QDir::Readable, QDirIterator::Subdirectories);
    while (iterator.hasNext())
        scripts << iterator.next();
    if (scripts.size() != 1)
    {
        emit error(scripts.isEmpty()
                   ? tr("The NXP firmware package does not contain uuu.auto.")
                   : tr("The NXP firmware package contains more than one uuu.auto script."));
        return;
    }

    QString uuu = findUuuExecutable();
    const QDir scriptDirectory(QFileInfo(scripts.first()).absolutePath());
    if (uuu.isEmpty())
    {
#ifdef Q_OS_WIN
        const QString packagedUuu = scriptDirectory.filePath(QStringLiteral("uuu.exe"));
#else
        const QString packagedUuu = scriptDirectory.filePath(QStringLiteral("uuu"));
#endif
        const QFileInfo packagedInfo(packagedUuu);
        if (packagedInfo.exists() && packagedInfo.isFile())
        {
            QFile::setPermissions(packagedUuu, packagedInfo.permissions() |
                                  QFileDevice::ExeOwner | QFileDevice::ExeUser |
                                  QFileDevice::ExeGroup | QFileDevice::ExeOther);
            uuu = packagedUuu;
        }
    }
    if (uuu.isEmpty())
    {
        emit error(tr("NXP UUU is not installed and the firmware package does not include it. Place uuu beside OpenHD ImageWriter or install it in PATH."));
        return;
    }

    emit preparationStatusUpdate(tr("Flashing the NXP device with UUU..."));
    QProcess process;
    process.setWorkingDirectory(scriptDirectory.absolutePath());
    process.setProcessChannelMode(QProcess::MergedChannels);
    process.start(uuu, QStringList() << QFileInfo(scripts.first()).fileName());
    if (!process.waitForStarted(5000))
    {
        emit error(tr("Could not start NXP UUU: %1").arg(process.errorString()));
        return;
    }

    QByteArray output;
    QRegularExpression percentageExpression(QStringLiteral("(\\d{1,3})%"));
    while (process.state() != QProcess::NotRunning)
    {
        if (_cancelled)
        {
            process.kill();
            process.waitForFinished(3000);
            return;
        }
        process.waitForReadyRead(100);
        output += process.readAll();
        const QString recent = QString::fromLocal8Bit(output.right(4096));
        QRegularExpressionMatchIterator matches = percentageExpression.globalMatch(recent);
        int percentage = -1;
        while (matches.hasNext())
            percentage = matches.next().captured(1).toInt();
        if (percentage >= 0 && percentage <= 100)
            emit writeProgress(percentage, 100);
    }
    output += process.readAll();
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0)
    {
        QString detail = QString::fromLocal8Bit(output).trimmed().section(QLatin1Char('\n'), -1);
        emit error(tr("NXP UUU flashing failed with exit code %1.%2")
                   .arg(process.exitCode())
                   .arg(detail.isEmpty() ? QString() : QStringLiteral(" ") + detail));
        return;
    }

    emit writeProgress(100, 100);
    emit finalizing();
    emit success();
}
