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
    property bool openHdDeviceAvailable: false

    signal navigate(string view)
    signal languageRequested()
    signal infoRequested()
    signal helpRequested()

    color: "#18222d" // Match background color from app style (screenshot side panel)

    ColumnLayout {
        anchors.fill: parent

        anchors.leftMargin: root.compact ? 8 : 12
        anchors.rightMargin: root.compact ? 8 : 12
        anchors.topMargin: 0
        anchors.bottomMargin: 0

        spacing: 4

        // ============================================================
        // Small amount of breathing room below the title bar
        // ============================================================

        Item {
            Layout.preferredHeight: 12
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
                    "label": qsTr("Choose image")
                },
                {
                    "view": "configure",
                    "icon": "../icons/ui/settings.svg",
                    "label": qsTr("Settings")
                },
                {
                    "view": "fleetcontrol",
                    "icon": "../icons/ui/fleetcontrol.svg",
                    "label": qsTr("FleetControl")
                }
            ]

            delegate: Button {
                id: navButton

                visible: true
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 52 : 0

                hoverEnabled: true
                padding: 0

                onClicked: root.navigate(modelData.view)

                background: Rectangle {
                    radius: 8

                    color: {
                        if (root.currentView === modelData.view)
                            return "#1867a1" // Solid blue selected state

                        if (navButton.hovered)
                            return "#202e3c"

                        return "transparent"
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
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
            Layout.preferredHeight: 46
            Layout.bottomMargin: 8

            hoverEnabled: true
            padding: 0

            onClicked: root.infoRequested()

            background: Rectangle {
                radius: 8

                color:
                    infoButton.hovered
                    ? "#202e3c"
                    : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }
            }

            contentItem: Item {
                Image {
                    width: 18
                    height: 18

                    sourceSize.width: 36
                    sourceSize.height: 36

                    anchors.left: parent.left

                    anchors.leftMargin:
                        root.compact
                        ? (parent.width - width) / 2
                        : 16

                    anchors.verticalCenter: parent.verticalCenter

                    source: "../icons/ui/info.svg"
                    fillMode: Image.PreserveAspectFit

                    opacity:
                        infoButton.hovered
                        ? 0.95
                        : 0.65
                }

                Text {
                    visible: !root.compact

                    anchors.left: parent.left
                    anchors.leftMargin: 48

                    anchors.verticalCenter: parent.verticalCenter

                    text: qsTr("Info")

                    color:
                        infoButton.hovered
                        ? "#e6f0f7"
                        : "#a1b8c7"

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

        Button {
            id: helpButton

            Layout.fillWidth: true
            Layout.preferredHeight: 46
            Layout.bottomMargin: 12

            hoverEnabled: true
            padding: 0

            onClicked: root.helpRequested()

            background: Rectangle {
                radius: 8

                color:
                    helpButton.hovered
                    ? "#202e3c"
                    : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }
            }

            contentItem: Item {
                Image {
                    width: 18
                    height: 18

                    sourceSize.width: 36
                    sourceSize.height: 36

                    anchors.left: parent.left

                    anchors.leftMargin:
                        root.compact
                        ? (parent.width - width) / 2
                        : 16

                    anchors.verticalCenter: parent.verticalCenter

                    source: "../icons/ui/info.svg" // Just reusing info.svg or similar if help doesn't exist
                    fillMode: Image.PreserveAspectFit

                    opacity:
                        helpButton.hovered
                        ? 0.95
                        : 0.65
                }

                Text {
                    visible: !root.compact

                    anchors.left: parent.left
                    anchors.leftMargin: 48

                    anchors.verticalCenter: parent.verticalCenter

                    text: qsTr("Help")

                    color:
                        helpButton.hovered
                        ? "#e6f0f7"
                        : "#a1b8c7"

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
                root.compact && helpButton.hovered

            ToolTip.text:
                qsTr("Help")

            ToolTip.delay:
                400
        }
    }
}
