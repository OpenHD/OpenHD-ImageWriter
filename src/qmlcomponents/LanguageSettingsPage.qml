import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property var languages: []
    property string currentLanguage: ""
    property string pendingLanguage: ""
    property string appliedLanguage: ""
    readonly property bool narrow: width < 720

    signal languageSelected(string language)
    signal backRequested()

    focus: visible
    onVisibleChanged: {
        if (visible) {
            appliedLanguage = currentLanguage
            pendingLanguage = currentLanguage
            languageSelector.currentIndex = languageSelector.find(pendingLanguage)
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

            PageBackButton {
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
                    text: qsTr("Select a language, then choose Apply.")
                    color: "#9fb3bf"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                ComboBox {
                    id: languageSelector
                    Layout.fillWidth: true
                    model: root.languages
                    currentIndex: -1
                    onActivated: root.pendingLanguage = currentText
                }

                ModernActionButton {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("Apply")
                    primary: true
                    enabled: root.pendingLanguage.length > 0 &&
                             root.pendingLanguage !== root.appliedLanguage
                    onClicked: {
                        root.appliedLanguage = root.pendingLanguage
                        root.languageSelected(root.pendingLanguage)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
