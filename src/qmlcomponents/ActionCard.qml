import QtQuick 2.9
import QtQuick.Controls 2.2

Button {
    id: root

    property url iconSource
    property string eyebrow: ""
    property string description: ""
    property string actionText: qsTr("Choose")
    property bool primaryAction: false

    hoverEnabled: true
    padding: 0
    implicitHeight: 176

    background: Rectangle {
        radius: 10
        color: !root.enabled ? "#10242f"
              : root.down ? "#102e40"
              : root.hovered ? "#112d3d"
              : "#0e2734"
        border.color: root.activeFocus ? "#62b7ff"
                    : root.primaryAction && root.enabled ? "#168df3"
                    : root.hovered ? "#3b6579"
                    : "#294654"
        border.width: root.primaryAction && root.enabled ? 2 : 1

        Behavior on color { ColorAnimation { duration: 110 } }
        Behavior on border.color { ColorAnimation { duration: 110 } }
    }

    contentItem: Item {
        opacity: root.enabled ? 1 : 0.55

        Rectangle {
            id: iconPlate
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.topMargin: 18
            width: 44
            height: 44
            radius: 9
            color: root.primaryAction && root.enabled ? "#0b79d0" : "#173747"

            Image {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                opacity: root.enabled ? 1 : 0.65
            }
        }

        Text {
            anchors.left: iconPlate.right
            anchors.right: parent.right
            anchors.top: iconPlate.top
            anchors.leftMargin: 13
            anchors.rightMargin: 16
            text: root.eyebrow.toUpperCase()
            color: "#7893a3"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.7
            elide: Text.ElideRight
        }

        Text {
            anchors.left: iconPlate.right
            anchors.right: parent.right
            anchors.top: iconPlate.top
            anchors.topMargin: 16
            anchors.leftMargin: 13
            anchors.rightMargin: 16
            text: root.text
            color: "#f3f7fa"
            font.pixelSize: 15
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: iconPlate.bottom
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 14
            text: root.description
            color: "#9db0bb"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 18
            anchors.bottomMargin: 16
            text: root.actionText
            color: root.enabled ? "#4aaaff" : "#718793"
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 18
            anchors.bottomMargin: 13
            text: "\u203a"
            color: root.enabled ? "#d7e5ed" : "#718793"
            font.pixelSize: 23
        }
    }
}
