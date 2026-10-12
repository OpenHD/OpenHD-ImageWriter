#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QDebug>
#include <iostream>
class Owner : public QObject {
    Q_OBJECT
public:
    QString raw = R"({"version":1,"components":{"100":{"AIR_RECORDING_E":2},"191":{"CUSTOM_NEW":7}}})";
    Q_INVOKABLE QString getValue(const QString&) const { return raw; }
    Q_INVOKABLE void setSetting(const QString &key,const QVariant &value) { raw=value.toString();emit settingChanged(key,value); }
signals:
    void settingChanged(const QString &key,const QVariant &value);
};
int main(int argc,char**argv) {
    QGuiApplication app(argc,argv); app.setOrganizationName("OpenHDSettingsQmlTests");app.setApplicationName("Defaults");
    QFile catalog(":/doc/openhd_settings_map.json");if(!catalog.open(QIODevice::ReadOnly)) return 1;
    const auto map=QJsonDocument::fromJson(catalog.readAll()).object();
    Owner owner; QQmlEngine engine;
    QQmlComponent component(&engine,QUrl::fromLocalFile(QStringLiteral(INITIAL_SETTINGS_QML_PATH)));
    QObject* panel=component.beginCreate(engine.rootContext());
    if(!panel) {qCritical()<<component.errors();return 2;}
    panel->setProperty("settingsOwner",QVariant::fromValue(static_cast<QObject*>(&owner)));
    panel->setProperty("fields",map.value("initialFields").toArray().toVariantList());panel->setProperty("role","air");
    component.completeCreate();engine.globalObject().setProperty("panel",engine.newQObject(panel));
    panel->setProperty("fields",map.value("initialFields").toArray().toVariantList());panel->setProperty("role","air");
    const auto exported=[&] { const auto value=engine.evaluate("JSON.stringify(panel.exportDefaults())");
      if(value.isError()) std::cerr<<value.toString().toStdString()<<std::endl;
      return QJsonDocument::fromJson(value.toString().toUtf8()).object();};
    auto values=exported().value("components").toObject().value("100").toObject();
    if(values.value("AIR_RECORDING_E").toInt()!=2 || exported().value("components").toObject().value("191").toObject().value("CUSTOM_NEW").toInt()!=7) return 3;
    owner.setSetting("initialParameterDefaults",QStringLiteral("{\"version\":1,\"components\":{}}"));
    if(!exported().value("components").toObject().isEmpty()) return 4;
    owner.setSetting("initialParameterDefaults",QStringLiteral(R"({"version":1,"components":{"100":{"AIR_RECORDING_E":1},"191":{"CUSTOM_NEW":7}}})"));
    panel->setProperty("role","ground");values=exported().value("components").toObject().value("100").toObject();
    if(!values.isEmpty() || exported().value("components").toObject().value("191").toObject().value("CUSTOM_NEW").toInt()!=7) return 5;
    delete panel;std::cout<<"INITIAL SETTINGS QML PROFILE REFRESH AND ROLE FILTER PASSED"<<std::endl;return 0;
}
#include "initialsettings_qml_test.moc"
