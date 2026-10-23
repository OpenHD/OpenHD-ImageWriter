#include "updateuploadthread.h"
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QDebug>

static bool write(const QString &path, const QByteArray &data)
{
    QFile f(path);
    return f.open(QIODevice::WriteOnly) && f.write(data) == data.size();
}

static QByteArray read(const QString &path)
{
    QFile f(path);
    return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
}

static bool transfer(const QString &source, const QString &mount, const QString &name,
                     const QByteArray &sha, bool shouldSucceed)
{
    UpdateUploadThread worker(source, mount, QStringLiteral("openhd"), name, sha);
    bool success = false;
    QString error;
    QObject::connect(&worker, &UpdateUploadThread::success, &worker,
                     [&]() { success = true; }, Qt::DirectConnection);
    QObject::connect(&worker, &UpdateUploadThread::error, &worker,
                     [&](const QString &message) { error = message; }, Qt::DirectConnection);
    worker.start();
    if (!worker.wait(10000)) {
        worker.cancel(); worker.wait();
        qCritical() << "Update copy timed out";
        return false;
    }
    if (success != shouldSucceed || (shouldSucceed ? !error.isEmpty() : error.isEmpty())) {
        qCritical() << "Unexpected copy result:" << success << error;
        return false;
    }
    return true;
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QTemporaryDir tmp;
    const QString mount = tmp.filePath("card");
    QDir().mkpath(mount + "/openhd");
    const QByteArray payload("complete system and application update");
    const QByteArray sha = QCryptographicHash::hash(payload, QCryptographicHash::Sha256).toHex();
    const QString source = tmp.filePath("source.ohd_base");
    if (!write(source, payload) || !write(mount + "/old.ohd", "old") ||
        !write(mount + "/old.ohd_base", "old")) return 1;
    if (!transfer(source, mount, "release.ohd_base", sha, true) ||
        read(mount + "/release.ohd_base") != payload ||
        QFile::exists(mount + "/openhd/release.ohd_base") ||
        QFile::exists(mount + "/old.ohd") || QFile::exists(mount + "/old.ohd_base")) return 1;

    // A bad download must not replace an already verified package.
    if (!write(source, "corrupt") || !transfer(source, mount, "release.ohd_base", sha, false) ||
        read(mount + "/release.ohd_base") != payload) return 1;

    // Choosing an application-only update must remove a stale full update too,
    // otherwise the device would prefer the older .ohd_base at boot.
    if (!write(source, payload) || !transfer(source, mount, "apps.ohd", sha, true) ||
        read(mount + "/apps.ohd") != payload || QFile::exists(mount + "/release.ohd_base")) return 1;
    qInfo() << "Full/application updates copied to card root with filename, checksum and stale-file handling intact";
    return 0;
}
