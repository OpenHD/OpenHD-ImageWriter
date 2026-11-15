#include "vectormapcatalog.h"
#include "vectorpack.h"

#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QUuid>

namespace {
constexpr qint64 maxPackBytes = 1024LL * 1024 * 1024;
struct Region {
    const char *name;
    const char *path;
    int approximateMegabytes;
};
constexpr Region catalog[] {
    {QT_TRANSLATE_NOOP("VectorMapCatalog", "Belgium"), "belgium", 803},
    {QT_TRANSLATE_NOOP("VectorMapCatalog", "Berlin"), "germany/berlin", 49},
    {QT_TRANSLATE_NOOP("VectorMapCatalog", "Bremen"), "germany/bremen", 28},
    {QT_TRANSLATE_NOOP("VectorMapCatalog", "Hamburg"), "germany/hamburg", 87},
    {QT_TRANSLATE_NOOP("VectorMapCatalog", "Luxembourg"), "luxembourg", 59},
    {QT_TRANSLATE_NOOP("VectorMapCatalog", "North Rhine-Westphalia"), "germany/nordrhein-westfalen", 829},
    {QT_TRANSLATE_NOOP("VectorMapCatalog", "Saarland"), "germany/saarland", 49}
};
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
    for (const auto &region : catalog)
        result.append(tr("%1 (~%2 MB)").arg(tr(region.name)).arg(region.approximateMegabytes));
    return result;
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
    if (busy() || index < 0 || index >= int(sizeof(catalog) / sizeof(catalog[0]))) return;
    const QString slug = QString::fromLatin1(catalog[index].path);
    const QString filename = slug.section('/', -1) + "-shortbread-1.0.mbtiles";
    const auto defaultBase = QStringLiteral("https://download.geofabrik.de/europe/");
    const QUrl base(qEnvironmentVariable("OPENHD_MAP_CATALOG_BASE_URL", defaultBase));
    const QDir directory(packageDirectory().toLocalFile());
    if (!QDir().mkpath(directory.absolutePath())) {
        finish(tr("Cannot create the offline maps folder."));
        return;
    }
    const auto target = directory.filePath(filename);
    if (QFileInfo(target).size() <= maxPackBytes && isShortbreadVectorPack(target)) {
        finish(tr("Map selected."));
        emit selected(target);
        return;
    }

    m_partial.reset(new QTemporaryFile(directory.filePath(".map-download-XXXXXX")));
    if (!m_partial->open()) {
        finish(tr("Cannot write to the offline maps folder."));
        return;
    }
    const auto url = base.resolved(QUrl(slug + "-shortbread-1.0.mbtiles"));
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "OpenHD-ImageWriter/1.0 (+https://openhd.org)");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::SameOriginRedirectPolicy);
    auto *reply = m_network.get(request);
    m_reply = reply;
    m_progress = 0;
    m_status = tr("Downloading %1…").arg(tr(catalog[index].name));
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
    connect(reply, &QNetworkReply::finished, this, [this, reply, drain, target] {
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
        if (!isShortbreadVectorPack(m_partial->fileName())) {
            finish(tr("The download is not a valid Shortbread vector map."));
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
