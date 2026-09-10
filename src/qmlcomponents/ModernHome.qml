import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property string statusMessage: ""
    signal featureRequested(string view)

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: contentColumn
            width: Math.min(parent.width - 64, 980)
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30
            spacing: 22

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(150, Math.min(230, root.height * 0.34))

                Image {
                    anchors.centerIn: parent
                    width: Math.min(parent.width * 0.78, 620)
                    height: parent.height
                    source: "../icons/openhd_imagewriter_logo_v4.png"
                    fillMode: Image.PreserveAspectFit
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: qsTr("What would you like to do?")
                    color: "#f4f8fb"
                    font.bold: true
                    font.pixelSize: 22
                }

                Text {
                    text: qsTr("Write, update, and configure OpenHD media from one place.")
                    color: "#9fb3c0"
                    font.pixelSize: 13
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 760 ? 3 : (width >= 480 ? 2 : 1)
                columnSpacing: 14
                rowSpacing: 14

                FeatureCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 178
                    iconSource: "../icons/ui/image.svg"
                    title: qsTr("Write an image")
                    description: qsTr("Choose an OpenHD image and write it safely to an SD card, USB drive, or supported device.")
                    onClicked: root.featureRequested("flash")
                }

                FeatureCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 178
                    iconSource: "../icons/ui/update.svg"
                    title: qsTr("Update a device")
                    description: qsTr("Download a current OpenHD release and install an update directly on the selected target.")
                    onClicked: root.featureRequested("update")
                }

                FeatureCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 178
                    iconSource: "../icons/ui/settings.svg"
                    title: qsTr("Configure media")
                    description: qsTr("Prepare device roles, cameras, networking, and advanced OpenHD settings before first boot.")
                    onClicked: root.featureRequested("configure")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusText.implicitHeight + 24
                visible: root.statusMessage !== ""
                radius: 6
                color: "#332d16"
                border.color: "#806b1c"

                Text {
                    id: statusText
                    anchors.fill: parent
                    anchors.margins: 12
                    text: root.statusMessage
                    color: "#ffe28a"
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                }
            }
        }
    }
}
