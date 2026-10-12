import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import Qt.labs.settings 1.0

GroupBox {
    id: panel
    title: qsTr("Initial OpenHD parameters")
    property var fields: []
    property var settingsOwner: null
    property string role: ""
    property var defaults: ({version: 1, components: {}})
    readonly property var visibleFields: fields.filter(function(f) {
        return f.provision && f.provision.roles.indexOf(role) >= 0
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
        Label { text: qsTr("Applied only when OpenHD creates new settings. Existing user settings are preserved."); wrapMode: Text.WordWrap; Layout.fillWidth: true }
        Repeater {
            model: panel.visibleFields
            delegate: ColumnLayout {
                Layout.fillWidth: true
                property var field: modelData
                CheckBox {
                    text: field.label
                    checked: panel.hasValue(field)
                    onClicked: panel.setValue(field, panel.value(field), checked)
                }
                ComboBox {
                    visible: field.choices && field.choices.length > 0
                    enabled: panel.hasValue(field)
                    Layout.fillWidth: true
                    model: field.choices || []
                    textRole: "label"
                    currentIndex: {
                        for (var n=0; n<model.length; ++n) if (model[n].value === panel.value(field)) return n
                        return 0
                    }
                    onActivated: panel.setValue(field, model[currentIndex].value, true)
                }
                TextField {
                    visible: !field.choices || field.choices.length === 0
                    enabled: panel.hasValue(field)
                    Layout.fillWidth: true
                    text: String(panel.value(field))
                    onEditingFinished: panel.setValue(field, field.type === "int32" ? Number(text) : text, true)
                }
            }
        }
    }
}
