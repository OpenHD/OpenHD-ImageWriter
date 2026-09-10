import QtQuick 2.9
import QtQuick.Controls 2.2

Button {
    id: root

    property url iconSource
    property string title: ""
    property string description: ""
    property bool compact: false
    property bool showChevron: true

    hoverEnabled: true
    padding: 0
    implicitHeight: compact ? 78 : 92

    background: Rectangle {
        radius: 8
        color: !root.enabled ? "#0d202b"
              : root.down ? "#17394b"
              : root.hovered ? "#142f3f"
              : "#102734"
        border.width: 1
        border.color: root.activeFocus ? "#55adf6"
                    : root.hovered ? "#3c6273"
                    : "#294754"

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
    }

    contentItem: Item {
        opacity: root.enabled ? 1 : 0.5

        Image {
            id: itemIcon
            anchors.left: parent.left
            anchors.leftMargin: root.compact ? 15 : 22
            anchors.verticalCenter: parent.verticalCenter
            width: root.compact ? 45 : 58
            height: width
            source: root.iconSource
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
        }

        Column {
            anchors.left: itemIcon.right
            anchors.leftMargin: root.compact ? 14 : 20
            anchors.right: chevron.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                width: parent.width
                text: root.title
                color: "#f2f6f9"
                font.pixelSize: root.compact ? 14 : 16
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.description
                color: "#a8bbc6"
                font.pixelSize: root.compact ? 11 : 13
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: root.compact ? 15 : 22
            anchors.verticalCenter: parent.verticalCenter
            text: "\u203a"
            color: root.hovered ? "#62b7ff" : "#c5d4dc"
            font.pixelSize: 31
            font.weight: Font.Light
            visible: root.showChevron
        }
    }
}
