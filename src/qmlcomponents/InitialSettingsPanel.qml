import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import Qt.labs.settings 1.0

GroupBox {
    id: panel
    title: qsTr("Air recording")
    property var fields: []
    property var settingsOwner: null
    property string role: ""
    property var defaults: ({version: 1, components: {}})
    readonly property var visibleFields: fields.filter(function(f) {
        return f.id === "AIR_RECORDING_E" && f.provision && f.provision.roles.indexOf(role) >= 0
    })
    visible: visibleFields.length > 0
    Settings { id: store; property string initialParameterDefaults: "{}" }
    Component.onCompleted: {
        loadDefaults(settingsOwner ? settingsOwner.getValue("initialParameterDefaults") : store.initialParameterDefaults)
    }
    function loadDefaults(raw) {
        try { var d = JSON.parse(raw); if (d.version === 1 && d.components) { defaults = d; return } } catch(e) {}
        defaults = {version: 1, components: {}}
    }
    Connections {
        target: panel.settingsOwner
        function onSettingChanged(key, value) { if (key === "initialParameterDefaults") panel.loadDefaults(String(value)) }
    }
    function hasValue(field) {
        var values = defaults.components[String(field.provision.componentId)]
        return !!(values && values[field.id] !== undefined)
    }
    function value(field) {
        var values = defaults.components[String(field.provision.componentId)]
        return hasValue(field) ? values[field.id] : field.choices && field.choices.length ? field.choices[0].value : field.type === "int32" ? 0 : ""
    }
    function setValue(field, value, enabled) {
        var copy = JSON.parse(JSON.stringify(defaults))
        var component = String(field.provision.componentId)
        if (!copy.components[component]) copy.components[component] = {}
        if (enabled) copy.components[component][field.id] = value
        else delete copy.components[component][field.id]
        defaults = copy
        store.initialParameterDefaults = JSON.stringify(copy)
        if (settingsOwner) settingsOwner.setSetting("initialParameterDefaults", JSON.stringify(copy))
    }
    function exportDefaults() {
        // Preserve explicit file parameters that a newer firmware knows about.
        var result = JSON.parse(JSON.stringify(defaults))
        // Never provision a disabled live stream, including from legacy profiles.
        Object.keys(result.components).forEach(function(component) {
            delete result.components[component].STREAMING_E
        })
        if (role === "ground") { delete result.components["100"]; delete result.components["101"] }
        fields.forEach(function(field) {
            if (!field.provision || field.provision.roles.indexOf(role) >= 0) return
            var values = result.components[String(field.provision.componentId)]
            if (values) delete values[field.id]
        })
        return result
    }
    ColumnLayout {
        anchors.fill: parent
        Label {
            text: qsTr("Save video locally on the air unit. Live video streaming stays on.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Repeater {
            model: panel.visibleFields
            delegate: ModernComboBox {
                property var field: modelData
                Layout.fillWidth: true
                model: [
                    {label: qsTr("Always off"), value: 0},
                    {label: qsTr("Always on"), value: 1},
                    {label: qsTr("When armed"), value: 2}
                ]
                textRole: "label"
                currentIndex: panel.hasValue(field) ? Number(panel.value(field)) : 0
                onActivated: panel.setValue(field, model[currentIndex].value, true)
            }
        }
        Label {
            text: qsTr("When armed requires flight-controller telemetry. Applied when OpenHD creates new camera settings.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
