import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property var languages: []
    property string currentLanguage: ""
    readonly property bool narrow: width < 720

    signal languageSelected(string language)
    signal backRequested()

    focus: visible
    onVisibleChanged: {
        if (visible) {
            languageSelector.currentIndex = languageSelector.find(currentLanguage)
            forceActiveFocus()
        }
    }
    Keys.onEscapePressed: backRequested()

    ColumnLayout {
        width: Math.min(parent.width - (root.narrow ? 36 : 72), 920)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: root.narrow ? 24 : 34
        anchors.bottomMargin: root.narrow ? 20 : 30
        spacing: 22

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            PageHeader {
                Layout.fillWidth: true
                title: qsTr("Language")
                subtitle: qsTr("Choose the language used throughout OpenHD ImageWriter.")
            }

            Button {
                text: qsTr("Back")
                flat: true
                onClicked: root.backRequested()
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Application language")

            ColumnLayout {
                width: parent.width
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: qsTr("The interface updates immediately after you select a language.")
                    color: "#9fb3bf"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                ComboBox {
                    id: languageSelector
                    Layout.fillWidth: true
                    model: root.languages
                    currentIndex: -1
                    onActivated: root.languageSelected(editText)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
