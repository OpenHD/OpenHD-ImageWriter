#include "offlinemapbuilder.h"
#include <QDataStream>
#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QImage>
#include <QNetworkReply>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QThread>
#include <cmath>
#include <functional>
#include <iostream>

static bool waitFor(const std::function<bool()>& condition, int timeout = 10000) {
    QElapsedTimer timer; timer.start();
    while (!condition() && timer.elapsed() < timeout) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
        QThread::msleep(1);
    }
    return condition();
}
#define CHECK(test) do { if (!(test)) { std::cerr << "Failed at line " << __LINE__ << ": " #test "\n"; return 1; } } while(false)

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    const auto args = app.arguments();
    if (args.size() == 4 && args[1] == "--styled-luxembourg") {
        OfflineMapBuilder builder(nullptr, args[3]);
        QString path;
        QObject::connect(&builder, &OfflineMapBuilder::generated, &app, [&](const QString& result) { path = result; });
        const auto generate = [&] {
            builder.generateStyled(QUrl::fromLocalFile(args[2]), "Luxembourg City",
                                   49.605, 6.117, 49.617, 6.143, 16);
        };
        generate();
        CHECK(builder.busy());
        builder.cancel();
        CHECK(path.isEmpty());
        generate();
        CHECK(waitFor([&] { return !builder.busy(); }, 120000));
        if (path.isEmpty()) std::cerr << builder.status().toStdString() << '\n';
        CHECK(!path.isEmpty() && builder.progress() == 1.0);
        QFile package(path);
        CHECK(package.open(QIODevice::ReadOnly));
        CHECK(package.read(8) == QByteArray("GLDMAP1\0", 8));
        CHECK(package.size() > 100000);
        std::cout << path.toStdString() << '\n';
        return 0;
    }
    QTemporaryDir output; CHECK(output.isValid());
    QTcpServer server; CHECK(server.listen(QHostAddress::LocalHost, 0));
    bool invalidData = false;
    int requests = 0;
    QObject::connect(&server, &QTcpServer::newConnection, &app, [&] {
        while (auto* socket = server.nextPendingConnection()) {
            QObject::connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
            QObject::connect(socket, &QTcpSocket::readyRead, socket, [&, socket] {
                auto data = socket->property("request").toByteArray() + socket->readAll();
                socket->setProperty("request", data);
                if (!data.contains("\r\n\r\n") || socket->property("answered").toBool()) return;
                const int headerEnd = data.indexOf("\r\n\r\n");
                int contentLength = 0;
                for (const auto& line : data.left(headerEnd).split('\n'))
                    if (line.toLower().startsWith("content-length:")) contentLength = line.mid(15).trimmed().toInt();
                if (data.size() < headerEnd + 4 + contentLength) return;
                socket->setProperty("answered", true); ++requests;
                const QByteArray body = data.startsWith("GET /search")
                    ? QByteArray("[{\"display_name\":\"Test region\",\"boundingbox\":[\"49.999\",\"50.001\",\"7.999\",\"8.001\"]}]")
                    : invalidData ? QByteArray("{\"remark\":\"timeout\",\"elements\":[]}")
                    : QByteArray("{\"elements\":[{\"tags\":{\"highway\":\"primary\"},\"geometry\":[{\"lat\":49.998,\"lon\":7.998},{\"lat\":50.002,\"lon\":8.002}]}]}");
                socket->write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "
                              + QByteArray::number(body.size()) + "\r\nConnection: close\r\n\r\n" + body);
                socket->disconnectFromHost();
            });
        }
    });
    const auto base = QByteArray("http://127.0.0.1:") + QByteArray::number(server.serverPort());
    qputenv("OPENHD_MAP_SEARCH_URL", base + "/search");
    qputenv("OPENHD_MAP_DATA_URL", base + "/data");
    OfflineMapBuilder builder(nullptr, output.path());
    CHECK(builder.previewCacheDirectory() != builder.mapCacheDirectory("osm"));
    CHECK(builder.mapCacheDirectory("osm") != builder.mapCacheDirectory("openhd_offline"));
    CHECK(QDir(builder.previewCacheDirectory()).exists());
    CHECK(builder.tileCount(50, 8, 50, 9, 15) == -1);
    CHECK(builder.tileCount(49, 7, 51, 9, 15) == -1);
    CHECK(builder.tileCount(49.999, 7.999, 50.001, 8.001, 15) > 0);
    CHECK(builder.tileCount(49.999, 7.999, 50.001, 8.001, 99) == -1);
    CHECK(builder.tileCount(49.55, 7.30, 50.45, 8.70, 14) > 0);
    CHECK(builder.tileCount(49.55, 7.30, 50.45, 8.70, 16) > 0);
    builder.search("Test region");
    CHECK(waitFor([&] { return !builder.searching(); }));
    CHECK(builder.searchResults().size() == 1);
    CHECK(builder.searchResults()[0].toMap()["name"].toString() == "Test region");
    QString path;
    QObject::connect(&builder, &OfflineMapBuilder::generated, &app, [&](const QString& result) { path = result; });
    builder.generate("Test field", 49.999, 7.999, 50.001, 8.001, 15);
    CHECK(waitFor([&] { return !builder.busy(); }));
    CHECK(!path.isEmpty()); CHECK(builder.progress() == 1.0);
    QFile package(path); CHECK(package.open(QIODevice::ReadOnly)); CHECK(package.read(8) == QByteArray("GLDMAP1\0", 8)); package.close();
    CHECK(package.open(QIODevice::ReadOnly));
    QDataStream stream(&package); stream.setByteOrder(QDataStream::LittleEndian);
    stream.setFloatingPointPrecision(QDataStream::DoublePrecision);
    package.seek(8);
    quint32 version, tileCount; quint16 tileSize, nameLength, attributionLength;
    quint8 minZoom, maxZoom; double south, west, north, east;
    stream >> version >> tileSize >> minZoom >> maxZoom >> south >> west >> north >> east
           >> nameLength >> attributionLength >> tileCount;
    CHECK(version == 1 && tileSize == 256 && minZoom == 0 && maxZoom == 15 && tileCount > 0);
    package.seek(56 + nameLength + attributionLength);
    quint8 z; quint32 x, y, size; quint64 offset;
    stream >> z >> x >> y >> offset >> size;
    CHECK(offset >= 56 + nameLength + attributionLength + tileCount * 21);
    CHECK(package.seek(offset));
    const QImage image = QImage::fromData(package.read(size), "PNG");
    CHECK(image.size() == QSize(256, 256));
    package.close();
    path.clear(); invalidData = true;
    builder.generate("Incomplete", 49.999, 7.999, 50.001, 8.001, 15);
    CHECK(waitFor([&] { return !builder.busy(); })); CHECK(path.isEmpty());
    CHECK(QDir(output.path()).entryList({"*.glidemap"}, QDir::Files).size() == 1);
    builder.generate("Cancelled", 49.999, 7.999, 50.001, 8.001, 15); builder.cancel();
    CHECK(!builder.busy()); CHECK(path.isEmpty());
    CHECK(QDir(output.path()).entryList({"*.glidemap"}, QDir::Files).size() == 1);
    invalidData = false;
    path.clear();
    const int requestsBeforeRadius = requests;
    builder.generate("50 km radius", 49.55, 7.30, 50.45, 8.70, 14);
    CHECK(waitFor([&] { return !builder.busy(); }, 60000));
    if (path.isEmpty()) std::cerr << builder.status().toStdString() << "\n";
    CHECK(!path.isEmpty());
    CHECK(builder.progress() == 1.0);
    CHECK(requests - requestsBeforeRadius > 2); // Large geometry is fetched in sections.
    std::cout << "Search, bounds, generation, GLDMAP1 package, invalid data, and cancellation passed (" << requests << " fixture requests).\n";
    return 0;
}
