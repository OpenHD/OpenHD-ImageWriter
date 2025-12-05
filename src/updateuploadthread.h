/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2024 OpenHD
 */

#ifndef UPDATEUPLOADTHREAD_H
#define UPDATEUPLOADTHREAD_H

#include <QThread>

class UpdateUploadThread : public QThread
{
    Q_OBJECT
public:
    UpdateUploadThread(const QString &sourceFile, const QString &targetMountpoint, QObject *parent = nullptr);

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
};

#endif // UPDATEUPLOADTHREAD_H
