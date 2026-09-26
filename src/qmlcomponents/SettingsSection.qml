import QtQuick 2.9
import QtQuick.Controls 2.2

GroupBox {
    id: root
    clip: true

    property url iconSource
    property string description: ""
    property color surfaceColor: "#0e2734"
    property color outlineColor: "#20556e"
    property real surfaceRadius: 9

    topPadding: iconSource.toString().length > 0 || description.length > 0 ? 50 : 30
    leftPadding: iconSource.toString().length > 0 ? 50 : 12
    rightPadding: 12
    bottomPadding: 12

    label: Item {
        x: 12
        y: 8
        width: root.width - 24
        height: root.topPadding - 18

        Image {
            id: sectionIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            visible: root.iconSource.toString().length > 0
            source: root.iconSource
            sourceSize.width: 192
            sourceSize.height: 192
            fillMode: Image.PreserveAspectFit
        }

        Column {
            anchors.left: sectionIcon.visible ? sectionIcon.right : parent.left
            anchors.leftMargin: sectionIcon.visible ? 12 : 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: root.title
                color: "#eef5f9"
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.description.length > 0
                text: root.description
                color: "#83a3b5"
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }
    }

    background: Rectangle {
        y: 0
        height: root.height
        radius: root.surfaceRadius
        color: root.surfaceColor
        border.color: root.outlineColor
        border.width: 1
    }
}
