/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2024 OpenHD
 */

#ifndef UPDATEUPLOADTHREAD_H
#define UPDATEUPLOADTHREAD_H

#include <QThread>
#include <atomic>

class UpdateUploadThread : public QThread
{
    Q_OBJECT
public:
    UpdateUploadThread(const QString &sourceFile, const QString &targetMountpoint,
                       const QString &targetSubdirectory, const QString &destinationFileName,
                       const QByteArray &expectedSha256, QObject *parent = nullptr);
    void cancel();

signals:
    void progress(qreal percentage);
    void status(const QString &statusMessage);
    void success();
    void error(const QString &message);

protected:
    void run() override;

private:
    QString _source;
    QString _mountpoint;
    QString _targetSubdirectory;
    QString _destinationFileName;
    QByteArray _expectedSha256;
    std::atomic<bool> _cancelled{false};
};

#endif // UPDATEUPLOADTHREAD_H
