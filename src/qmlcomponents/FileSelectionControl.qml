import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property string selectedPath: ""
    property string placeholderText: qsTr("No file selected")

    signal chooseRequested()
    signal clearRequested()

    implicitWidth: 280
    implicitHeight: fileLayout.implicitHeight

    ColumnLayout {
        id: fileLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 6
            color: "#173244"
            border.width: 1
            border.color: "#31566b"
            clip: true

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.selectedPath.length > 0 ? root.selectedPath : root.placeholderText
                color: root.selectedPath.length > 0 ? "#dce8ef" : "#718694"
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }

            MouseArea {
                id: pathHover
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
            }

            ToolTip.visible: pathHover.containsMouse && root.selectedPath.length > 0
            ToolTip.text: root.selectedPath
        }

        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 8

            ModernActionButton {
                id: chooseButton
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                text: qsTr("Choose file")
                onClicked: root.chooseRequested()

                primary: true
            }

            ModernActionButton {
                id: clearButton
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                text: qsTr("Clear")
                enabled: root.selectedPath.length > 0
                onClicked: root.clearRequested()

            }
        }
    }
}
