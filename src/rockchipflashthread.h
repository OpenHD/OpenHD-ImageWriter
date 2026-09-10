#ifndef ROCKCHIPFLASHTHREAD_H
#define ROCKCHIPFLASHTHREAD_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QThread>
#include <QUrl>
#include <QString>
#include <QVariant>
#include <atomic>

class RockchipFlashThread : public QThread
{
    Q_OBJECT
public:
    RockchipFlashThread(const QUrl &source, const QString &deviceId, QObject *parent = nullptr);
    virtual ~RockchipFlashThread();

    void cancel();

signals:
    void preparationStatusUpdate(QVariant msg);
    void writeProgress(QVariant now, QVariant total);
    void finalizing();
    void success();
    void error(QVariant msg);

protected:
    void run() override;

private:
    QUrl _source;
    QString _deviceId;
    std::atomic<bool> _cancelled{false};

    bool extractZip(const QString &zipPath, const QString &destDir, QString *errorMsg);
};

#endif // ROCKCHIPFLASHTHREAD_H
