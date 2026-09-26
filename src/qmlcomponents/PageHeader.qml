import QtQuick 2.9

Column {
    id: root

    property string title: ""
    property string subtitle: ""

    spacing: 5

    Text {
        width: root.width
        text: root.title
        color: "#f3f7fa"
        font.pixelSize: 25
        font.bold: true
        elide: Text.ElideRight
    }

    Text {
        width: root.width
        text: root.subtitle
        color: "#9db0bb"
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
}
