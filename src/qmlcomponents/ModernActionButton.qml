import QtQuick 2.9
import QtQuick.Controls 2.2

Button {
    id: root

    property bool primary: false
    property bool danger: false

    implicitWidth: Math.max(92, buttonLabel.implicitWidth + 28)
    implicitHeight: 38
    leftPadding: 14
    rightPadding: 14
    hoverEnabled: true

    contentItem: Text {
        id: buttonLabel
        text: root.text
        color: !root.enabled ? "#667b88"
             : root.primary || root.danger ? "#ffffff" : "#dce8ef"
        font.pixelSize: 12
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 6
        color: {
            if (!root.enabled)
                return "#152b38"
            if (root.danger)
                return root.down ? "#8f2f35" : root.hovered ? "#b23c43" : "#9d343b"
            if (root.primary)
                return root.down ? "#08639e" : root.hovered ? "#1186cf" : "#0b73b8"
            return root.down ? "#1d3d50" : root.hovered ? "#203f51" : "#183445"
        }
        border.width: root.activeFocus ? 2 : 1
        border.color: {
            if (!root.enabled)
                return "#243f4f"
            if (root.danger)
                return "#d15a61"
            if (root.primary)
                return root.activeFocus ? "#73cdff" : "#179be7"
            return root.activeFocus ? "#52b8f6" : "#315f77"
        }

        Behavior on color { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }
    }
}
