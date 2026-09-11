import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Rectangle {
    id: root

    /*
     * Width is controlled by main.qml through:
     *
     *     width: window.navigationWidth
     *
     * Keep implicitWidth only as a sensible fallback.
     */
    implicitWidth: 230

    property string currentView: "home"
    property bool compact: width < 100

    signal navigate(string view)
    signal languageRequested()
    signal infoRequested()
    signal helpRequested()

    color: "#0d1c2a"

    ColumnLayout {
        anchors.fill: parent

        anchors.leftMargin: root.compact ? 5 : 8
        anchors.rightMargin: root.compact ? 5 : 8
        anchors.topMargin: 0
        anchors.bottomMargin: 0

        spacing: 0

        // ============================================================
        // Small amount of breathing room below the title bar
        // ============================================================

        Item {
            Layout.preferredHeight: 8
        }

        // ============================================================
        // Main navigation
        // ============================================================

        Repeater {
            model: [
                {
                    "view": "home",
                    "icon": "../icons/ui/home.svg",
                    "label": qsTr("Home")
                },
                {
                    "view": "flash",
                    "icon": "../icons/ui/drive.svg",
                    "label": qsTr("Write image")
                },
                {
                    "view": "update",
                    "icon": "../icons/ui/update.svg",
                    "label": qsTr("Update device")
                },
                {
                    "view": "configure",
                    "icon": "../icons/ui/settings.svg",
                    "label": qsTr("Configure media")
                }
            ]

            delegate: Button {
                id: navButton

                Layout.fillWidth: true
                Layout.preferredHeight: 60

                hoverEnabled: true
                padding: 0

                onClicked: root.navigate(modelData.view)

                background: Rectangle {
                    radius: 3

                    color: {
                        if (root.currentView === modelData.view)
                            return "#173a57"

                        if (navButton.hovered)
                            return "#132838"

                        return "transparent"
                    }

                    border.width:
                        root.currentView === modelData.view ? 0 : 0

                    border.color: "#245f86"

                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }

                    // Thin blue accent strip on the active entry
                    Rectangle {
                        visible: root.currentView === modelData.view

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        width: 3

                        color: "#168df3"

                        radius: 2
                    }
                }

                contentItem: Item {
                    Image {
                        width: 17
                        height: 17

                        sourceSize.width: 34
                        sourceSize.height: 34

                        anchors.left: parent.left

                        anchors.leftMargin:
                            root.compact
                            ? (parent.width - width) / 2
                            : 13

                        anchors.verticalCenter: parent.verticalCenter

                        source: modelData.icon
                        fillMode: Image.PreserveAspectFit

                        opacity: {
                            if (root.currentView === modelData.view)
                                return 1.0

                            if (navButton.hovered)
                                return 0.95

                            return 0.78
                        }
                    }

                    Text {
                        visible: !root.compact

                        anchors.left: parent.left
                        anchors.leftMargin: 43

                        anchors.right: parent.right
                        anchors.rightMargin: 8

                        anchors.verticalCenter: parent.verticalCenter

                        text: modelData.label

                        color: {
                            if (root.currentView === modelData.view)
                                return "#ffffff"

                            if (navButton.hovered)
                                return "#d6e1e8"

                            return "#b4c2cc"
                        }

                        font.pixelSize: 14
                        font.bold: false

                        elide: Text.ElideNone

                        Behavior on color {
                            ColorAnimation {
                                duration: 80
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onPressed: mouse.accepted = false
                }

                ToolTip.visible:
                    root.compact && navButton.hovered

                ToolTip.text:
                    modelData.label

                ToolTip.delay:
                    400
            }
        }

        // ============================================================
        // Empty center space
        // ============================================================

        Item {
            Layout.fillHeight: true
        }

        // ============================================================
        // Bottom Info
        // ============================================================

        Button {
            id: infoButton

            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.bottomMargin: 8

            hoverEnabled: true
            padding: 0

            onClicked: root.infoRequested()

            background: Rectangle {
                radius: 3

                color:
                    infoButton.hovered
                    ? "#132838"
                    : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 80
                    }
                }
            }

            contentItem: Item {
                Image {
                    width: 16
                    height: 16

                    sourceSize.width: 32
                    sourceSize.height: 32

                    anchors.left: parent.left

                    anchors.leftMargin:
                        root.compact
                        ? (parent.width - width) / 2
                        : 13

                    anchors.verticalCenter: parent.verticalCenter

                    source: "../icons/ui/info.svg"
                    fillMode: Image.PreserveAspectFit

                    opacity:
                        infoButton.hovered
                        ? 0.95
                        : 0.78
                }

                Text {
                    visible: !root.compact

                    anchors.left: parent.left
                    anchors.leftMargin: 43

                    anchors.verticalCenter: parent.verticalCenter

                    text: qsTr("Info")

                    color:
                        infoButton.hovered
                        ? "#d6e1e8"
                        : "#b4c2cc"

                    font.pixelSize: 13
                    font.bold: false
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse.accepted = false
            }

            ToolTip.visible:
                root.compact && infoButton.hovered

            ToolTip.text:
                qsTr("Info")

            ToolTip.delay:
                400
        }
    }
}