// ComboBoxGroup.qml
import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0

GroupBox {
    property string groupTitle
    property string visibleIf
    property string settingKey
    property var optionsList
    property var popup


    title: groupTitle
    Layout.fillWidth: true
    visible: Qt.binding(function() { return eval(visibleIf); })

    ColumnLayout {
        ComboBox {
            id: comboBox
            model: optionsList
            Layout.minimumWidth: 200
            Layout.maximumHeight: 40
            onCurrentTextChanged: {
                imageWriter.setSetting(settingKey, currentText);
                popup[settingKey] = currentText;
            }
        }
    }
}

