import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

SettingsSection {
    id: root
    property int cacheRevision: 0
    title: qsTr("Downloaded image cache")
    implicitWidth: 0
    implicitHeight: cacheContent.implicitHeight + topPadding + bottomPadding
    surfaceColor: "#152130"
    outlineColor: "#1e3347"
    surfaceRadius: 10

    function formatSize(bytes) {
        var value = Number(bytes || 0)
        if (value < 1024 * 1024)
            return Math.round(value / 1024) + " KB"
        return (value / (1024 * 1024 * 1024)).toFixed(value >= 10 * 1024 * 1024 * 1024 ? 0 : 1) + " GB"
    }

    Connections {
        target: imageWriter
        function onCacheChanged() { root.cacheRevision++ }
    }

    ColumnLayout {
        id: cacheContent
        width: root.availableWidth
        spacing: 8

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: qsTr("Cached images can be written again without downloading them. The limit is normally enforced at the selected size, but one larger image is always kept complete.")
            color: "#9fb3bf"
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Text { text: qsTr("Cache limit"); color: "#e4eef4"; font.pixelSize: 10; Layout.fillWidth: true }
            SpinBox {
                from: 1
                to: 1000
                editable: true
                value: imageWriter.cacheLimitGb()
                onValueModified: imageWriter.setCacheLimitGb(value)
            }
            Text { text: qsTr("GB"); color: "#9fb3bf"; font.pixelSize: 10 }
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: qsTr("Currently using %1").arg(root.formatSize(imageWriter.cacheSizeBytes() + root.cacheRevision * 0))
            color: "#83b8d6"
            font.pixelSize: 10
        }

        ModernActionButton {
            Layout.alignment: Qt.AlignRight
            Layout.maximumWidth: root.availableWidth
            text: qsTr("Remove downloaded image cache")
            enabled: imageWriter.cacheSizeBytes() + root.cacheRevision * 0 > 0
            onClicked: clearCacheDialog.open()
        }
    }

    Dialog {
        id: clearCacheDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: qsTr("Remove downloaded image cache?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: imageWriter.clearImageCache()
        contentItem: Text {
            width: 340
            text: qsTr("All images downloaded by OpenHD ImageWriter will be removed. You can download them again later.")
            color: "#e4eef4"
            wrapMode: Text.WordWrap
        }
    }
}
