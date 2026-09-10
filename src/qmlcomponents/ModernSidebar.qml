import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Rectangle {
    id: root

    property string currentView: "home"
    property bool compact: width < 150
    signal navigate(string view)
    signal languageRequested()

    color: "#0b1c27"
    border.color: "#1d3543"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 8 : 12
        spacing: 6

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 50

            Rectangle {
                width: 28
                height: 28
                radius: 14
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: "#0d84ff"

                Text {
                    anchors.centerIn: parent
                    text: "O"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 13
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.compact
                text: qsTr("OpenHD ImageWriter")
                color: "#f4f8fb"
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: 13
            }
        }

        Repeater {
            model: [
                { "view": "home", "glyph": "⌂", "label": qsTr("Home") },
                { "view": "flash", "glyph": "▣", "label": qsTr("Write image") },
                { "view": "update", "glyph": "↧", "label": qsTr("Update device") },
                { "view": "configure", "glyph": "⚙", "label": qsTr("Configure media") }
            ]

            delegate: Button {
                id: navButton
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                hoverEnabled: true
                padding: 0
                onClicked: root.navigate(modelData.view)

                background: Rectangle {
                    radius: 6
                    color: root.currentView === modelData.view
                           ? "#075fab"
                           : (navButton.hovered ? "#132e3e" : "transparent")
                    border.color: root.currentView === modelData.view ? "#168df3" : "transparent"
                }

                contentItem: Item {
                    Text {
                        width: root.compact ? parent.width : 34
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.glyph
                        color: root.currentView === modelData.view ? "white" : "#c7d7e2"
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 18
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 38
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.compact
                        text: modelData.label
                        color: root.currentView === modelData.view ? "white" : "#c7d7e2"
                        elide: Text.ElideRight
                        font.pixelSize: 13
                    }
                }

                ToolTip.visible: root.compact && hovered
                ToolTip.text: modelData.label
                ToolTip.delay: 500
            }
        }

        Item { Layout.fillHeight: true }

        Button {
            id: languageButton
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            hoverEnabled: true
            padding: 0
            onClicked: root.languageRequested()

            background: Rectangle {
                radius: 6
                color: languageButton.hovered ? "#132e3e" : "transparent"
            }

            contentItem: Item {
                Text {
                    width: root.compact ? parent.width : 34
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "文"
                    color: "#c7d7e2"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 15
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 38
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.compact
                    text: qsTr("Language")
                    color: "#c7d7e2"
                    elide: Text.ElideRight
                    font.pixelSize: 13
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            visible: !root.compact
            text: "v" + imageWriter.constantVersion()
            color: "#718897"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 11
        }
    }
}
