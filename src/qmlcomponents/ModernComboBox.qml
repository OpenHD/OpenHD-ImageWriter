import QtQuick 2.9
import QtQuick.Controls 2.2
import "SettingsLabels.js" as SettingsLabels

ComboBox {
    id: root

    implicitHeight: 40
    leftPadding: 14
    rightPadding: 40
    hoverEnabled: true

    contentItem: Text {
        leftPadding: 0
        rightPadding: 0
        text: SettingsLabels.translated(root.displayText)
        color: root.enabled ? "#e7f0f5" : "#718694"
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Item {
        x: root.width - width - 12
        y: (root.height - height) / 2
        width: 18
        height: 18

        Text {
            anchors.centerIn: parent
            text: "\u2304"
            color: root.enabled ? "#a9c4d4" : "#607582"
            font.pixelSize: 18
            font.bold: true
        }
    }

    background: Rectangle {
        radius: 6
        color: root.down ? "#1b3a4d" : root.hovered ? "#19374a" : "#173244"
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? "#28a7ef"
                      : root.hovered ? "#39718f"
                      : "#31566b"
        Behavior on color { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 280)
        padding: 6

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            radius: 7
            color: "#102a39"
            border.width: 1
            border.color: "#356984"
        }
    }

    delegate: ItemDelegate {
        id: optionDelegate
        width: root.width - 12
        height: 38
        highlighted: root.highlightedIndex === index

        contentItem: Text {
            text: SettingsLabels.translated(root.textAt(index))
            color: optionDelegate.highlighted ? "#ffffff" : "#c8d9e3"
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 5
            color: optionDelegate.highlighted ? "#176da5" : "transparent"
        }
    }
}
