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
        anchors.margins: root.compact ? 9 : 14
        spacing: 7

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 58 : 68

            Image {
                width: root.compact ? 30 : parent.width
                height: root.compact ? 30 : 60
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                source: root.compact ? "../icons/openhdimagewriter.ico"
                                     : "../icons/openhd_imagewriter_logo_v4.png"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 42
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: false
                text: qsTr("OpenHD ImageWriter")
                color: "#f4f8fb"
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: 13
            }
        }

        Repeater {
            model: [
                { "view": "home", "icon": "../icons/ui/home.svg", "label": qsTr("Home") },
                { "view": "flash", "icon": "../icons/ui/image.svg", "label": qsTr("Write image") },
                { "view": "update", "icon": "../icons/ui/update.svg", "label": qsTr("Update device") },
                { "view": "configure", "icon": "../icons/ui/settings.svg", "label": qsTr("Configure media") }
            ]

            delegate: Button {
                id: navButton
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                hoverEnabled: true
                padding: 0
                onClicked: root.navigate(modelData.view)

                background: Rectangle {
                    radius: 7
                    color: root.currentView === modelData.view
                           ? "#0b64ad"
                           : (navButton.hovered ? "#132e3e" : "transparent")
                    border.color: root.currentView === modelData.view ? "#188fe9" : "transparent"
                }

                contentItem: Item {
                    Image {
                        width: 20
                        height: 20
                        anchors.left: parent.left
                        anchors.leftMargin: root.compact ? (parent.width - width) / 2 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        source: modelData.icon
                        fillMode: Image.PreserveAspectFit
                        opacity: root.currentView === modelData.view ? 1 : 0.78
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 42
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
                Image {
                    width: 20
                    height: 20
                    anchors.left: parent.left
                    anchors.leftMargin: root.compact ? (parent.width - width) / 2 : 10
                    anchors.verticalCenter: parent.verticalCenter
                    source: "../icons/ui/language.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.78
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 42
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
