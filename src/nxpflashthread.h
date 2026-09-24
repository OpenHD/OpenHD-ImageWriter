#ifndef NXPFLASHTHREAD_H
#define NXPFLASHTHREAD_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QThread>
#include <QUrl>
#include <QVariant>
#include <atomic>

class NxpFlashThread : public QThread
{
    Q_OBJECT
public:
    explicit NxpFlashThread(const QUrl &source, QObject *parent = nullptr);
    ~NxpFlashThread() override;

    void cancel();
    static QString findUuuExecutable();

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
    std::atomic<bool> _cancelled{false};

    bool extractArchive(const QString &archivePath, const QString &destination,
                        QString *errorMessage);
};

#endif // NXPFLASHTHREAD_H
