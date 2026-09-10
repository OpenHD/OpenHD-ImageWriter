import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property var deviceModel: null
    property string title: qsTr("Choose a target")
    property string subtitle: qsTr("Select the device that should receive the image.")
    readonly property bool narrow: width < 720

    signal deviceSelected(var device)
    signal backRequested()
    signal refreshRequested()

    focus: visible
    Keys.onEscapePressed: backRequested()

    ColumnLayout {
        width: Math.min(parent.width - (root.narrow ? 36 : 72), 1150)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: root.narrow ? 24 : 30
        anchors.bottomMargin: root.narrow ? 18 : 28
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            PageHeader {
                Layout.fillWidth: true
                title: root.title
                subtitle: root.subtitle
            }

            Button {
                text: qsTr("Refresh")
                flat: true
                onClicked: root.refreshRequested()
            }

            Button {
                text: qsTr("Back")
                flat: true
                onClicked: root.backRequested()
            }
        }

        ListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.deviceModel
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: SelectionRow {
                width: deviceList.width
                compact: root.narrow
                title: model.description || model.device
                description: root.deviceDescription(model)
                iconSource: "../icons/ui/drive.svg"
                enabled: !model.isReadOnly
                onClicked: root.deviceSelected({
                    "device": model.device,
                    "description": model.description,
                    "size": model.size,
                    "isReadOnly": model.isReadOnly,
                    "isUsb": typeof(model.isUsb) !== "undefined" && model.isUsb,
                    "isScsi": typeof(model.isScsi) !== "undefined" && model.isScsi,
                    "isMaskrom": typeof(model.isMaskrom) !== "undefined" && model.isMaskrom,
                    "isLoader": typeof(model.isLoader) !== "undefined" && model.isLoader,
                    "mountpoints": typeof(model.mountpoints) !== "undefined" ? model.mountpoints : []
                })
            }

            footer: Item { width: 1; height: 4 }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            visible: deviceList.count === 0
            radius: 8
            color: "#0e2532"
            border.color: "#294754"

            Column {
                anchors.centerIn: parent
                spacing: 8

                BusyIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 28
                    height: 28
                    running: parent.parent.visible
                }

                Text {
                    text: qsTr("Searching for removable devices...")
                    color: "#9fb3bf"
                    font.pixelSize: 13
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: safetyText.implicitHeight + 26
            radius: 8
            color: "#2b2512"
            border.color: "#66551b"

            Text {
                id: safetyText
                anchors.fill: parent
                anchors.margins: 13
                text: qsTr("All data on the selected target will be erased. Verify the device name and capacity before continuing.")
                color: "#f2d77f"
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
            }
        }
    }

    function deviceDescription(device) {
        var details = []
        if (device.size) {
            var bytes = Number(device.size)
            if (bytes > 0)
                details.push((bytes / 1000000000).toFixed(1) + " GB")
        }
        if (device.isMaskrom)
            details.push(qsTr("MaskROM recovery mode"))
        else if (device.isLoader)
            details.push(qsTr("Loader mode"))
        if (device.isReadOnly)
            details.push(qsTr("Write protected"))
        if (device.mountpoints && device.mountpoints.length)
            details.push(device.mountpoints.join(", "))
        return details.join("  •  ")
    }
}
