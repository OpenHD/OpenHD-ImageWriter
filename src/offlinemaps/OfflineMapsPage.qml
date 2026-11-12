import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Controls.Material 2.12
import QtQuick.Dialogs 1.3 as Dialogs
import QtQuick.Layouts 1.12

Item {
    id: root
    objectName: "offlineMapsPage"
    property var mainWindow
    property var builder: typeof _styledOfflineMapBuilder === "undefined" ? null : _styledOfflineMapBuilder
    property url archive: imageWriter.getValue("offlineMapCreatorArchive")
    readonly property var radii: [5, 10, 25, 50]
    readonly property bool operationInProgress: !!builder && (builder.busy || builder.searching)
    readonly property string stagedMap: mainWindow ? mainWindow.localOfflineMapPath : ""
    readonly property int tileCount: builder && picker.item && picker.item.selectionValid
        ? builder.tileCount(picker.item.south, picker.item.west, picker.item.north, picker.item.east, 13 + detail.currentIndex)
        : 0

    Material.theme: Material.Dark
    Material.accent: "#278cff"

    onVisibleChanged: if (visible && builder) loadPicker()
    Component.onCompleted: if (visible && builder) loadPicker()

    function loadPicker() {
        if (picker.active) return
        picker.setSource("OfflineMapSelection.qml", {
            tileCacheDirectory: builder.previewCacheDirectory,
            radiusMeters: radii[radius.currentIndex] * 1000,
            initialZoom: 3,
            fitInitialRadius: false
        })
        picker.active = true
    }

    function selectResult(index) {
        if (!picker.item || index < 0) return
        var result = builder.searchResults[index]
        picker.item.fitRegion(result)
        place.text = result.name.split(",")[0]
    }

    Connections {
        target: root.builder
        function onGenerated(filePath) {
            imageWriter.setSetting("offlineMapCreatorPackagePath", filePath)
        }
    }

    Dialogs.FileDialog {
        id: archiveDialog
        title: qsTr("Choose a Shortbread vector map")
        nameFilters: [qsTr("Shortbread vector maps (*.mbtiles)")]
        onAccepted: {
            root.archive = fileUrl
            imageWriter.setSetting("offlineMapCreatorArchive", String(fileUrl))
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 24
                spacing: 12

                Label {
                    text: qsTr("Offline maps")
                    font.pixelSize: 28
                    font.bold: true
                    color: "#f2f6fb"
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Create a map for QOpenHD. ImageWriter includes the selected map when you flash a Ground image.")
                    color: "#aebfca"
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    OfflineMapButton {
                        text: qsTr("Choose map data")
                        enabled: !root.operationInProgress
                        onClicked: archiveDialog.open()
                    }
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        text: String(root.archive).length
                            ? decodeURIComponent(String(root.archive).split("/").pop())
                            : qsTr("Choose a Shortbread .mbtiles file")
                        color: "#aebfca"
                    }
                    OfflineMapButton {
                        text: qsTr("Download data")
                        onClicked: Qt.openUrlExternally("https://shortbread-tiles.org/download/")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: place
                        Layout.fillWidth: true
                        placeholderText: qsTr("Town or region")
                        selectByMouse: true
                        enabled: root.builder && !root.operationInProgress
                        onAccepted: if (text.trim().length) root.builder.search(text)
                    }
                    OfflineMapButton {
                        text: qsTr("Find")
                        enabled: root.builder && place.text.trim().length > 0 && !root.operationInProgress
                        onClicked: root.builder.search(place.text)
                    }
                }
                ComboBox {
                    Layout.fillWidth: true
                    visible: count > 0
                    enabled: !root.operationInProgress
                    model: root.builder ? root.builder.searchResults : []
                    textRole: "name"
                    displayText: currentIndex >= 0 ? currentText : qsTr("Choose a result")
                    onActivated: root.selectResult(index)
                    onCountChanged: {
                        currentIndex = count === 1 ? 0 : -1
                        if (count === 1) root.selectResult(0)
                    }
                }

                Loader {
                    id: picker
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(230, Math.min(420, root.height - 360))
                    enabled: !root.operationInProgress
                    active: false
                }
                Label {
                    visible: picker.status === Loader.Error
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("The map picker requires the Qt Location and Positioning modules.")
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: width < 510 ? 2 : 4
                    enabled: !root.operationInProgress && !!picker.item
                    OfflineMapButton {
                        objectName: "selectMapCircle"
                        Layout.fillWidth: true
                        text: qsTr("Circle")
                        primary: !!picker.item && picker.item.radiusMode
                        onClicked: picker.item.selectCenterRadius()
                    }
                    OfflineMapButton {
                        Layout.fillWidth: true
                        text: picker.item && picker.item.drawing ? qsTr("Move map") : qsTr("Draw rectangle")
                        onClicked: {
                            picker.item.radiusMode = false
                            picker.item.drawing = !picker.item.drawing
                        }
                    }
                    ComboBox {
                        id: radius
                        Layout.fillWidth: true
                        model: root.radii.map(function(km) { return qsTr("%1 km radius").arg(km) })
                        currentIndex: 1
                        enabled: !!picker.item && picker.item.radiusMode
                        onActivated: picker.item.radiusMeters = root.radii[index] * 1000
                    }
                    ComboBox {
                        id: detail
                        Layout.fillWidth: true
                        model: [qsTr("Overview"), qsTr("Standard detail"), qsTr("High detail"), qsTr("Maximum detail")]
                        currentIndex: 1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: "#aebfca"
                        text: root.tileCount < 0 ? qsTr("Choose a smaller area or lower detail.")
                            : root.tileCount > 0 ? qsTr("%1 tiles").arg(root.tileCount) : qsTr("Select an area")
                    }
                    OfflineMapButton {
                        objectName: "cancelStyledMap"
                        text: qsTr("Cancel")
                        visible: root.operationInProgress
                        onClicked: root.builder.cancel()
                    }
                    OfflineMapButton {
                        objectName: "createStyledMap"
                        text: qsTr("Create map")
                        primary: true
                        enabled: String(root.archive).length > 0 && root.tileCount > 0 && !root.operationInProgress
                        onClicked: {
                            var area = picker.item
                            root.builder.generateStyled(root.archive, place.text, area.south, area.west,
                                                        area.north, area.east, 13 + detail.currentIndex)
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.builder ? root.builder.status : ""
                    wrapMode: Text.WordWrap
                    color: "#aebfca"
                }
                ProgressBar {
                    Layout.fillWidth: true
                    visible: root.operationInProgress
                    value: root.builder ? root.builder.progress : 0
                    indeterminate: value === 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.stagedMap.length > 0
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        color: "#cde9fd"
                        text: qsTr("Included on Ground flashes: %1").arg(root.stagedMap.split(/[\\/]/).pop())
                    }
                    OfflineMapButton {
                        text: qsTr("Open folder")
                        onClicked: Qt.openUrlExternally(root.builder.packageDirectory())
                    }
                    OfflineMapButton {
                        text: qsTr("Remove")
                        enabled: !root.operationInProgress
                        onClicked: imageWriter.setSetting("offlineMapCreatorPackagePath", "")
                    }
                }
                Label {
                    text: qsTr("Map data © OpenStreetMap contributors")
                    color: "#aebfca"
                    font.pixelSize: 11
                }
            }
        }
    }
}
