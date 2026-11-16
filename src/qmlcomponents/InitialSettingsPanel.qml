import QtQuick 2.9
import Qt.labs.settings 1.0

Item {
    id: panel
    visible: false
    property var fields: []
    property var settingsOwner: null
    property string role: ""
    property var defaults: ({version: 1, components: {}})
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
}
