import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

TabButton {
    id: root

    property url iconSource

    implicitHeight: 44
    hoverEnabled: true

    background: Rectangle {
        color: root.checked ? "#12374c" : (root.hovered ? "#102e40" : "#0e2634")
        border.width: 1
        border.color: "#254b60"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 3
            visible: root.checked
            color: "#129ff0"
        }
    }

    contentItem: RowLayout {
        spacing: 10
        Item { Layout.fillWidth: true }
        Image {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: root.iconSource
            sourceSize.width: 192
            sourceSize.height: 192
            fillMode: Image.PreserveAspectFit
            opacity: root.checked ? 1 : 0.85
        }
        Text {
            text: root.text
            color: root.checked ? "#16a8f5" : "#dbe7ed"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }
        Item { Layout.fillWidth: true }
    }
}
