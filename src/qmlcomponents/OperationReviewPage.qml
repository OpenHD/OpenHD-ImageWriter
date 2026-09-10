import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property string title: qsTr("Review operation")
    property string subtitle: qsTr("Confirm the source and target before continuing.")
    property string sourceName: ""
    property string targetName: ""
    property string confirmText: qsTr("Start")
    property bool updateOperation: false
    readonly property bool narrow: width < 720

    signal confirmed()
    signal backRequested()

    focus: visible
    Keys.onEscapePressed: backRequested()

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: Math.min(parent.width - (root.narrow ? 36 : 72), 920)
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.narrow ? 24 : 34
            spacing: 20

            PageHeader {
                Layout.fillWidth: true
                title: root.title
                subtitle: root.subtitle
            }

            SelectionRow {
                Layout.fillWidth: true
                compact: root.narrow
                title: root.sourceName
                description: root.updateOperation ? qsTr("Update package") : qsTr("Source image")
                iconSource: root.updateOperation ? "../icons/ui/update.svg" : "../icons/ui/image.svg"
                showChevron: false
            }

            SelectionRow {
                Layout.fillWidth: true
                compact: root.narrow
                title: root.targetName
                description: qsTr("Destination device")
                iconSource: "../icons/ui/drive.svg"
                showChevron: false
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: warningText.implicitHeight + 32
                radius: 8
                color: "#2c2511"
                border.color: "#75601c"

                Text {
                    id: warningText
                    anchors.fill: parent
                    anchors.margins: 16
                    text: root.updateOperation
                          ? qsTr("Keep the device connected and powered until the update has completed.")
                          : qsTr("All existing data on the target will be permanently erased.")
                    color: "#f5da82"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Back")
                    flat: true
                    onClicked: root.backRequested()
                }

                Button {
                    text: root.confirmText
                    onClicked: root.confirmed()
                }
            }
        }
    }
}
