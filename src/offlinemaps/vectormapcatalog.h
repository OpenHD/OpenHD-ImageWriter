#pragma once

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QTemporaryFile>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <memory>

class VectorMapCatalog final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList regions READ regions CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
public:
    explicit VectorMapCatalog(QObject *parent = nullptr, const QString &outputDirectory = {});
    QVariantList regions() const;
    bool busy() const { return m_reply != nullptr; }
    QString status() const { return m_status; }
    double progress() const { return m_progress; }
    Q_INVOKABLE void download(int index);
    Q_INVOKABLE void selectFile(const QUrl &url);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE QUrl packageDirectory() const;
signals:
    void changed();
    void selected(const QString &path);
private:
    void finish(const QString &message);
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    std::unique_ptr<QTemporaryFile> m_partial;
    QTimer m_timeout;
    QString m_status;
    QString m_outputDirectory;
    double m_progress = 0;
};
