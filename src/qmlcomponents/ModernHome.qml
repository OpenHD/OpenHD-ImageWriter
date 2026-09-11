import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property string statusMessage: ""
    signal featureRequested(string view)

    Rectangle {
        anchors.fill: parent
        color: "#0d1b26"
    }

    // Centered column containing logo + tagline + cards
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 860)
        spacing: 0

        // ─── Logo ──────────────────────────────────────────────────────────
        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth:  Math.min(parent.width - 40, 360)
            Layout.preferredHeight: Math.round(Layout.preferredWidth * (793 / 1983))
            sourceSize.width: 720
            source: "../icons/openhd_imagewriter_logo_v4.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true
        }

        Item { Layout.preferredHeight: 18 }

        // ─── Tagline ───────────────────────────────────────────────────────
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Open Source FPV for Everyone")
            color: "#8fafc4"
            font.pixelSize: 15
            font.letterSpacing: 0.3
        }

        Item { Layout.preferredHeight: 36 }

        // ─── Cards ─────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Repeater {
                model: [
                    {
                        "view": "flash",
                        "icon": "../icons/ui/drive.svg",
                        "title": qsTr("Write image"),
                        "desc":  qsTr("Write OpenHD to an SD card, USB drive, or supported device.")
                    },
                    {
                        "view": "update",
                        "icon": "../icons/ui/update.svg",
                        "title": qsTr("Update device"),
                        "desc":  qsTr("Download current OpenHD images and update your device.")
                    },
                    {
                        "view": "configure",
                        "icon": "../icons/ui/settings.svg",
                        "title": qsTr("Configure media"),
                        "desc":  qsTr("Adjust device roles, camera settings, WiFi, and advanced parameters.")
                    }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    radius: 10
                    color: cardMouse.containsMouse ? "#1a2e40" : "#152130"
                    border.color: cardMouse.containsMouse ? "#2a6fa8" : "#1e3347"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 32
                        spacing: 0

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            sourceSize.width: 72
                            sourceSize.height: 72
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            opacity: cardMouse.containsMouse ? 1.0 : 0.88
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }

                        Item { Layout.preferredHeight: 18 }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: "#e8f4fc"
                            font.pixelSize: 16
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.preferredHeight: 10 }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc
                            color: "#7a9eb8"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            lineHeight: 1.3
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.featureRequested(modelData.view)
                    }
                }
            }
        }

        // ─── Status message ────────────────────────────────────────────────
        Item { Layout.preferredHeight: 16; visible: root.statusMessage !== "" }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: statusText.implicitHeight + 20
            visible: root.statusMessage !== ""
            radius: 7
            color: "#2a2412"
            border.color: "#6a5518"

            Text {
                id: statusText
                anchors.fill: parent
                anchors.margins: 10
                text: root.statusMessage
                color: "#ffe08a"
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 12
            }
        }
    }
}
