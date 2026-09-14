import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Button {
    id: root

    property bool compact: false

    implicitWidth: compact ? 46 : 118
    implicitHeight: 40
    padding: 0
    hoverEnabled: true
    Accessible.name: qsTr("Back")

    background: Rectangle {
        radius: 8
        color: root.down ? "#173b50" : root.hovered ? "#123348" : "#0e2734"
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? "#52b8f6"
                      : root.hovered ? "#347b9d"
                      : "#28627d"

        Behavior on color { ColorAnimation { duration: 90 } }
        Behavior on border.color { ColorAnimation { duration: 90 } }
    }

    contentItem: RowLayout {
        spacing: root.compact ? 0 : 9

        Item { Layout.fillWidth: true }

        Image {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            source: "../icons/ui/back-arrow.svg"
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: root.enabled ? 1 : 0.45
        }

        Text {
            visible: !root.compact
            text: qsTr("Back")
            color: "#f1f6f9"
            font.pixelSize: 15
            font.bold: true
        }

        Item { Layout.fillWidth: true }
    }
}
