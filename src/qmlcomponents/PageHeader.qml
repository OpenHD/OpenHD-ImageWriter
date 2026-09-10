import QtQuick 2.9
import QtQuick.Layouts 1.3

ColumnLayout {
    id: root

    property string title: ""
    property string subtitle: ""

    spacing: 5

    Text {
        Layout.fillWidth: true
        text: root.title
        color: "#f3f7fa"
        font.pixelSize: 25
        font.bold: true
        elide: Text.ElideRight
    }

    Text {
        Layout.fillWidth: true
        text: root.subtitle
        color: "#9db0bb"
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
}
