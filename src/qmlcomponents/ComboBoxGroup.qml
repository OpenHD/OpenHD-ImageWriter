// ComboBoxGroup.qml
import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0

GroupBox {
    property string groupTitle
    property string visibleIf
    property string settingKey
    property var optionsList // Can be: [ "IMX219", "IMX477" ] or [ { brand, models } ]
    property var popup

    property bool isNested: optionsList.length > 0 && typeof optionsList[0] === "object"

    title: groupTitle
    Layout.fillWidth: true

    visible: Qt.binding(function() {
        // Only evaluate when popup is ready
        if (!popup || popup.bootType === undefined) {
            console.log(">> ComboBoxGroup hidden (popup or bootType undefined)");
            return false;
        }
        try {
            const result = (new Function("popup", "return (" + visibleIf + ")"))(popup);
            console.log(">> ComboBoxGroup visibility for", groupTitle, "=", result);
            return result;
        } catch (e) {
            console.warn("Failed to evaluate visibleIf:", visibleIf, e);
            return false;
        }
    })

    ColumnLayout {
        spacing: 10

        // Flat (single dropdown) mode
        ComboBox {
            id: flatComboBox
            visible: !isNested
            model: optionsList
            Layout.minimumWidth: 200
            Layout.maximumHeight: 40

            onCurrentIndexChanged: {
                var selected = currentText;
                imageWriter.setSetting(settingKey, selected);
                if (popup && popup.hasOwnProperty(settingKey)) {
                    popup[settingKey] = selected;
                }
            }

            Component.onCompleted: {
                var saved = imageWriter.getValue(settingKey);
                var idx = optionsList.indexOf(saved);
                if (idx >= 0) flatComboBox.currentIndex = idx;
            }
        }

        // Nested: brand selector
        ComboBox {
            id: brandCombo
            visible: isNested
            model: optionsList.map(b => b.brand)
            Layout.minimumWidth: 200
            Layout.maximumHeight: 40

            onCurrentIndexChanged: {
                updateModelOptions();
            }

            Component.onCompleted: {
                if (isNested) updateModelOptions();
            }
        }

        // Nested: model selector
        ComboBox {
            id: modelCombo
            visible: isNested
            model: []
            Layout.minimumWidth: 200
            Layout.maximumHeight: 40

            onCurrentIndexChanged: {
                var selected = currentText;
                imageWriter.setSetting(settingKey, selected);
                if (popup && popup.hasOwnProperty(settingKey)) {
                    popup[settingKey] = selected;
                }
            }
        }
    }

    function updateModelOptions() {
        if (!isNested || brandCombo.currentIndex < 0 || brandCombo.currentIndex >= optionsList.length) {
            console.warn("updateModelOptions skipped (invalid index or not nested)");
            return;
        }

        const models = optionsList[brandCombo.currentIndex].models;
        modelCombo.model = models;

        // Select previously saved value, if available
        var saved = imageWriter.getValue(settingKey);
        var idx = models.indexOf(saved);
        if (idx >= 0) {
            modelCombo.currentIndex = idx;
        } else {
            modelCombo.currentIndex = 0;
        }

        // Apply default
        const selected = modelCombo.currentText;
        imageWriter.setSetting(settingKey, selected);
        if (popup && popup.hasOwnProperty(settingKey)) {
            popup[settingKey] = selected;
        }
    }
}
