import QtQuick 2.9
import QtQuick.Controls 2.2

Button {
    id: root

    property string glyph: ""
    property string title: ""
    property string description: ""

    hoverEnabled: true
    padding: 0

    background: Rectangle {
        radius: 8
        color: root.down ? "#17384a" : (root.hovered ? "#142f40" : "#102633")
        border.color: root.hovered || root.activeFocus ? "#168df3" : "#294654"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: Item {
        Rectangle {
            id: iconPlate
            width: 54
            height: 54
            radius: 10
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 18
            color: root.hovered ? "#0d84ff" : "#1b394a"

            Text {
                anchors.centerIn: parent
                text: root.glyph
                color: "white"
                font.pixelSize: 27
                font.bold: true
            }
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.top: iconPlate.bottom
            anchors.topMargin: 14
            text: root.title
            color: "#f5f8fa"
            wrapMode: Text.WordWrap
            font.bold: true
            font.pixelSize: 16
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: root.description
            color: "#aebfca"
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            lineHeight: 1.15
        }
    }
}
