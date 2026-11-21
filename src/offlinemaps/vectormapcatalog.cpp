#include "vectormapcatalog.h"
#include "vectorpack.h"

#include <QDebug>
#include <QCryptographicHash>
#include <QRegularExpression>
#include <QDir>
#include <QFileInfo>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QUuid>

namespace {
constexpr qint64 maxPackBytes = 1024LL * 1024 * 1024;
bool matchesDigest(const QString &path, qint64 size, const QByteArray &digest)
{
    QFile file(path);
    QCryptographicHash hash(QCryptographicHash::Sha256);
    return file.size() == size && file.open(QIODevice::ReadOnly)
        && hash.addData(&file) && hash.result().toHex() == digest;
}

}

VectorMapCatalog::VectorMapCatalog(QObject *parent, const QString &outputDirectory)
    : QObject(parent), m_outputDirectory(outputDirectory)
{
    m_timeout.setSingleShot(true);
    m_timeout.setInterval(30000);
    connect(&m_timeout, &QTimer::timeout, this, [this] {
        finish(tr("The map download timed out. Try again."));
    });
}

QUrl VectorMapCatalog::packageDirectory() const
{
    const auto path = m_outputDirectory.isEmpty()
        ? QDir(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)).filePath("maps")
        : m_outputDirectory;
    return QUrl::fromLocalFile(path);
}

QVariantList VectorMapCatalog::regions() const
{
    QVariantList result;
    for (const auto &key : m_regions.keys()) {
        const auto region = m_regions.value(key).toObject();
        const auto size = region.value("map").toObject().value("size").toDouble();
        result.append(tr("%1 - %2 (%3 MB)").arg(region.value("country").toString(),
                      region.value("name").toString()).arg(qint64((size + 999999) / 1000000)));
    }
    return result;
}

void VectorMapCatalog::refresh()
{
    if (busy()) return;
    QNetworkRequest request(QUrl(QStringLiteral("https://downloads.librescoot.org/releases/maps-routing.json")));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    auto *reply = m_network.get(request);
    m_reply = reply;
    m_status = tr("Loading map regions...");
    m_timeout.start();
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (reply != m_reply) return;
        QJsonObject available;
        if (reply->error() == QNetworkReply::NoError && reply->bytesAvailable() <= 2 * 1024 * 1024) {
            const auto regions = QJsonDocument::fromJson(reply->readAll()).object().value("regions").toObject();
            for (auto it = regions.begin(); it != regions.end(); ++it) {
                const auto region = it.value().toObject();
                const auto map = region.value("map").toObject();
                const QUrl url(map.value("url").toString());
                const auto size = map.value("size").toDouble();
                if (url.scheme() == "https" && size > 0 && size <= maxPackBytes
                    && QRegularExpression("^[a-z0-9_-]+$").match(it.key()).hasMatch()
                    && QRegularExpression("^[0-9a-f]{64}$").match(map.value("sha256").toString()).hasMatch())
                    available.insert(it.key(), region);
            }
        }
        if (available.isEmpty()) {
            finish(tr("Could not load available map regions."));
            return;
        }
        m_regions = available;
        emit regionsChanged();
        finish(QString());
    });
    emit changed();
}

void VectorMapCatalog::selectFile(const QUrl &url)
{
    if (busy()) return;
    const QFileInfo info(url.toLocalFile());
    if (!info.isFile() || info.suffix().compare("mbtiles", Qt::CaseInsensitive) != 0
        || info.size() > maxPackBytes || !isShortbreadVectorPack(info.absoluteFilePath())) {
        finish(tr("Choose a valid Shortbread vector MBTiles file up to 1 GB."));
        return;
    }
    finish(tr("Map selected."));
    emit selected(info.absoluteFilePath());
}

void VectorMapCatalog::download(int index)
{
    if (busy() || index < 0 || index >= m_regions.size()) return;
    const auto slug = m_regions.keys().at(index);
    const auto region = m_regions.value(slug).toObject();
    const auto map = region.value("map").toObject();
    const QUrl url(map.value("url").toString());
    const auto digest = map.value("sha256").toString().toLatin1();
    const qint64 expectedSize = qint64(map.value("size").toDouble());
    const auto filename = QStringLiteral("tiles_%1_%2.mbtiles").arg(slug, QString::fromLatin1(digest.left(12)));
    const QDir directory(packageDirectory().toLocalFile());
    if (!QDir().mkpath(directory.absolutePath())) {
        finish(tr("Cannot create the offline maps folder."));
        return;
    }
    const auto target = directory.filePath(filename);
    if (matchesDigest(target, expectedSize, digest) && isShortbreadVectorPack(target)) {
        finish(tr("Map selected."));
        emit selected(target);
        return;
    }

    m_partial.reset(new QTemporaryFile(directory.filePath(".map-download-XXXXXX")));
    if (!m_partial->open()) {
        finish(tr("Cannot write to the offline maps folder."));
        return;
    }
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "OpenHD-ImageWriter/1.0 (+https://openhd.org)");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    auto *reply = m_network.get(request);
    m_reply = reply;
    m_progress = 0;
    m_status = tr("Downloading %1…").arg(region.value("name").toString());
    m_timeout.start();
    const auto drain = [this, reply] {
        if (m_reply != reply) return false;
        while (reply->bytesAvailable() > 0) {
            const auto bytes = reply->read(256 * 1024);
            if (bytes.isEmpty() || m_partial->pos() + bytes.size() > maxPackBytes
                || m_partial->write(bytes) != bytes.size()) {
                finish(tr("Could not save the map download. Check available storage."));
                return false;
            }
        }
        return true;
    };
    connect(reply, &QNetworkReply::readyRead, this, [this, drain] {
        if (drain()) m_timeout.start();
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this, reply](qint64 received, qint64 total) {
        if (m_reply != reply || total <= 0) return;
        const QStorageInfo storage(QFileInfo(m_partial->fileName()).absolutePath());
        if (total > maxPackBytes || (storage.isValid() && storage.bytesAvailable() < total - received)) {
            finish(tr("There is not enough storage for this map."));
            return;
        }
        m_progress = qBound(0.0, double(received) / double(total), 1.0);
        emit changed();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, drain, target, digest, expectedSize] {
        if (m_reply != reply) return;
        if (reply->error() != QNetworkReply::NoError
            || reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() != 200) {
            qWarning() << "Offline regional map download failed:" << reply->error()
                       << reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt()
                       << reply->errorString();
            finish(tr("Could not download the regional map. Check the connection and try again."));
            return;
        }
        if (!drain()) return;
        const auto size = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
        if (!m_partial->flush() || (size > 0 && size != m_partial->size())) {
            finish(tr("The map download was incomplete."));
            return;
        }
        m_partial->close();
        if (!matchesDigest(m_partial->fileName(), expectedSize, digest) || !isShortbreadVectorPack(m_partial->fileName())) {
            finish(tr("The map failed its checksum or format check."));
            return;
        }
        // Keep an existing file intact if it could not be opened above.
        const auto path = QFileInfo::exists(target)
            ? QFileInfo(target).absoluteDir().filePath(QUuid::createUuid().toString(QUuid::WithoutBraces)
                                                      + '-' + QFileInfo(target).fileName())
            : target;
        if (!m_partial->rename(path)) {
            finish(tr("Could not finish saving the map."));
            return;
        }
        m_partial->setAutoRemove(false);
        finish(tr("Map ready."));
        emit selected(path);
    });
    emit changed();
}

void VectorMapCatalog::cancel()
{
    if (busy()) finish(tr("Map download cancelled."));
}

void VectorMapCatalog::finish(const QString &message)
{
    auto *reply = m_reply.data();
    m_reply = nullptr;
    if (reply) {
        if (reply->isRunning()) reply->abort();
        reply->deleteLater();
    }
    m_timeout.stop();
    m_partial.reset();
    m_status = message;
    m_progress = 0;
    emit changed();
}
