import QtQuick 2.9
import QtQuick.Controls 2.2

// Compact row used inside a grouped list container.
// Height: ~54 px.  No individual card background — the outer grouped panel provides the surface.
Button {
    id: root

    property url iconSource
    property string title: ""
    property string description: ""
    property bool compact: false
    property bool showChevron: true
    property bool showSeparator: true   // 1-px bottom divider; hide on last row

    hoverEnabled: true
    padding: 0
    implicitHeight: 56

    background: Rectangle {
        color: root.down ? "#1a3348"
             : root.hovered ? "#162c3d"
             : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }

        // bottom divider
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 60
            height: 1
            color: "#1a2e3d"
            visible: root.showSeparator
        }
    }

    contentItem: Item {
        opacity: root.enabled ? 1 : 0.45

        // Platform icon
        Image {
            id: itemIcon
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            sourceSize.width: 72
            sourceSize.height: 72
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Title + description column
        Column {
            anchors.left: itemIcon.right
            anchors.leftMargin: 12
            anchors.right: chevron.visible ? chevron.left : parent.right
            anchors.rightMargin: chevron.visible ? 8 : 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: root.title
                color: "#e0edf7"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.description
                color: "#6e92a8"
                font.pixelSize: 12
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        // Chevron
        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "\u203a"
            color: root.hovered ? "#62b7ff" : "#4a6e84"
            font.pixelSize: 22
            font.weight: Font.Light
            visible: root.showChevron
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse.accepted = false
    }
}
