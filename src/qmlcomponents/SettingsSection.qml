import QtQuick 2.9
import QtQuick.Controls 2.2

GroupBox {
    id: root
    clip: true

    property url iconSource
    property string description: ""

    topPadding: iconSource.toString().length > 0 || description.length > 0 ? 58 : 34
    leftPadding: iconSource.toString().length > 0 ? 58 : 14
    rightPadding: 14
    bottomPadding: 14

    label: Item {
        x: 14
        y: 10
        width: root.width - 28
        height: root.topPadding - 18

        Image {
            id: sectionIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
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
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.description.length > 0
                text: root.description
                color: "#83a3b5"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    background: Rectangle {
        y: 0
        height: root.height
        radius: 9
        color: "#0e2734"
        border.color: "#20556e"
        border.width: 1
    }
}
