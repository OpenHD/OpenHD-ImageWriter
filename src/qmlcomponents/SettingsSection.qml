import QtQuick 2.9
import QtQuick.Controls 2.2

GroupBox {
    id: root

    topPadding: 42
    leftPadding: 18
    rightPadding: 18
    bottomPadding: 18

    label: Text {
        x: 18
        y: 15
        width: root.availableWidth - 36
        text: root.title
        color: "#eef5f9"
        font.pixelSize: 14
        font.bold: true
        elide: Text.ElideRight
    }

    background: Rectangle {
        y: 4
        height: root.height - 4
        radius: 8
        color: "#102734"
        border.color: "#294754"
        border.width: 1
    }
}
