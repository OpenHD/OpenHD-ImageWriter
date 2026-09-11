import QtQuick 2.9
import QtQuick.Controls 2.2

Button {
    id: root

    property url iconSource
    property string title: ""
    property string description: ""

    hoverEnabled: true
    padding: 0

    // Keep FeatureCard in sync but ModernHome now uses its own inline Repeater cards.
    // This component is no longer used by ModernHome but kept for potential other uses.
    background: Rectangle {
        radius: 10
        color: root.down ? "#12202e" : (root.hovered ? "#1a2e40" : "#152130")
        border.color: root.hovered || root.activeFocus ? "#2a6fa8" : "#1e3347"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }
    }

    contentItem: Column {
        spacing: 0
        anchors.centerIn: parent
        width: parent.width - 32

        Item { width: 1; height: 32 }

        Image {
            width: 54
            height: 54
            anchors.horizontalCenter: parent.horizontalCenter
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            opacity: root.hovered ? 1.0 : 0.88
            Behavior on opacity { NumberAnimation { duration: 130 } }
        }

        Item { width: 1; height: 18 }

        Text {
            width: parent.width
            text: root.title
            color: "#e8f4fc"
            font.pixelSize: 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Item { width: 1; height: 10 }

        Text {
            width: parent.width
            text: root.description
            color: "#7a9eb8"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.3
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse.accepted = false
    }
}
