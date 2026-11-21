#pragma once

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QUuid>

inline bool isShortbreadVectorPack(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly) || file.read(16) != QByteArray("SQLite format 3\0", 16))
        return false;
    file.close();

    const auto connection = QUuid::createUuid().toString();
    QHash<QString, QString> metadata;
    {
        auto database = QSqlDatabase::addDatabase("QSQLITE", connection);
        database.setConnectOptions("QSQLITE_OPEN_READONLY");
        database.setDatabaseName(path);
        if (database.open()) {
            QSqlQuery query(database);
            if (query.exec("SELECT name, value FROM metadata WHERE name IN "
                           "('format','bounds','minzoom','maxzoom','json') LIMIT 32")) {
                while (query.next()) metadata.insert(query.value(0).toString(), query.value(1).toString());
            }
            if (!query.exec("SELECT tile_data FROM tiles LIMIT 1") || !query.next()) metadata.clear();
        }
    }
    QSqlDatabase::removeDatabase(connection);
    const auto bounds = metadata.value("bounds").split(',');
    bool minOk = false, maxOk = false;
    const int minZoom = metadata.value("minzoom").toInt(&minOk);
    const int maxZoom = metadata.value("maxzoom").toInt(&maxOk);
    double coordinates[4] {};
    bool boundsOk = bounds.size() == 4;
    for (int index = 0; boundsOk && index < 4; ++index)
        coordinates[index] = bounds.at(index).toDouble(&boundsOk);
    QSet<QString> layers;
    const auto tileJson = QJsonDocument::fromJson(metadata.value("json").toUtf8()).object();
    for (const auto& layer : tileJson.value("vector_layers").toArray())
        layers.insert(layer.toObject().value("id").toString());
    return metadata.value("format") == "pbf" && layers.contains("streets") && (layers.contains("place_labels") || layers.contains("street_labels"))
        && minOk && maxOk && minZoom >= 0 && maxZoom >= minZoom && maxZoom <= 22 && boundsOk
        && coordinates[0] >= -180 && coordinates[0] < coordinates[2] && coordinates[2] <= 180
        && coordinates[1] >= -90 && coordinates[1] < coordinates[3] && coordinates[3] <= 90;
}
