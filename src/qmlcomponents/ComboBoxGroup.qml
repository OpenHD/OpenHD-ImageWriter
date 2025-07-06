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
        try {
            return (new Function("popup", "return (" + visibleIf + ")"))(popup);
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

        // Nested brand → model dropdowns
        ComboBox {
            id: brandCombo
            visible: isNested
            model: optionsList.map(b => b.brand)
            Layout.minimumWidth: 200
            Layout.maximumHeight: 40
            onCurrentIndexChanged: updateModelOptions()
        }

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

        function updateModelOptions() {
            if (!isNested || brandCombo.currentIndex < 0) return;
            modelCombo.model = optionsList[brandCombo.currentIndex].models;

            // optional: set default
            modelCombo.currentIndex = 0;
            imageWriter.setSetting(settingKey, modelCombo.currentText);
            if (popup && popup.hasOwnProperty(settingKey)) {
                popup[settingKey] = modelCombo.currentText;
            }
        }

        Component.onCompleted: {
            if (isNested) updateModelOptions();
        }
    }
}
