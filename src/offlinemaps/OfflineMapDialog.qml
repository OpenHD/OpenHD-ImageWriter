import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls.Material 2.12

// The map canvas is loaded only when requested, keeping QtLocation off the boot path.
Popup {
    id: root
    property var builder: typeof _offlineMapBuilder !== "undefined" ? _offlineMapBuilder : null
    property real initialLatitude: 0
    property real initialLongitude: 0
    property string mapboxApiKey: ""
    property bool fitInitialRadius: true
    property string generationOrigin: "https://openhd.tech"
    property var generationRequest: null
    property string downloadId: ""
    property string generationStatus: ""
    readonly property bool working: !!generationRequest || !!downloadId || (!!builder && builder.searching)
    property color panelColor: typeof settings_form !== "undefined" ? settings_form.panelBackgroundRaised : "#15283b"
    property color textColor: typeof settings_form !== "undefined" ? settings_form.primaryText : "#f2f6fb"
    Material.theme: typeof settings_form !== "undefined" && !settings_form.darkMode ? Material.Light : Material.Dark
    Material.accent: typeof settings_form !== "undefined" ? settings_form.accentColor : "#278cff"
    Material.foreground: textColor
    Material.background: panelColor
    signal mapReady(string filePath)
    parent: Overlay.overlay
    width: Math.min(parent.width - 24, 1000)
    height: Math.min(parent.height - 24, 720)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    modal: true
    focus: true
    padding: 16
    closePolicy: working ? Popup.NoAutoClose : Popup.CloseOnEscape
    background: Rectangle { color: root.panelColor; radius: 12; border.color: "#526775" }

    function stopGeneration(message) {
        var request = generationRequest
        generationRequest = null
        generationDeadline.stop()
        generationStatus = message
        if (request) request.abort()
    }

    function generateRegion() {
        if (working || !canvas.item || !canvas.item.selectionValid || canvas.item.drawing) return
        var area = canvas.item
        var name = region.text.trim().slice(0, 60) || qsTr("Offline map")
        var request = new XMLHttpRequest()
        generationStatus = qsTr("Creating vector map on FleetControl…")
        generationRequest = request
        request.open("POST", generationOrigin + "/api/imagewriter/maps/generate-region")
        request.setRequestHeader("Content-Type", "application/json")
        request.onreadystatechange = function() {
            if (request !== generationRequest || request.readyState !== XMLHttpRequest.DONE) return
            generationRequest = null
            generationDeadline.stop()
            var result = {}
            try { result = JSON.parse(request.responseText) } catch (error) {}
            if (request.status !== 201 || typeof result.id !== "string"
                    || typeof result.sha256 !== "string" || typeof result.downloadUrl !== "string"
                    || result.downloadUrl.indexOf("/api/region-download/") !== 0) {
                generationStatus = result.message || qsTr("Could not create this map. Try a smaller area or retry shortly.")
                return
            }
            downloadId = result.id
            generationStatus = qsTr("Downloading vector map…")
            imageWriter.stageFleetControlOfflineMap("custom-region", result.id,
                                                    generationOrigin + result.downloadUrl, result.sha256)
        }
        generationDeadline.restart()
        request.send(JSON.stringify({name: name, west: area.west, east: area.east,
                                    north: area.north, south: area.south}))
    }

    Timer {
        id: generationDeadline
        interval: 255000
        onTriggered: root.stopGeneration(qsTr("Map generation timed out. Try a smaller area."))
    }
    Connections {
        target: imageWriter
        function onFleetControlOfflineMapStaged(mapId, filePath, error) {
            if (!root.downloadId || mapId !== root.downloadId) return
            root.downloadId = ""
            root.generationStatus = error
            if (!error) root.mapReady(filePath)
        }
    }
    onOpened: {
        if (!root.builder || canvas.active) return
        if (root.builder.setMapboxKey) root.builder.setMapboxKey(root.mapboxApiKey)
        var mapbox = root.mapboxApiKey.trim().length > 0
        canvas.setSource("OfflineMapSelection.qml", {
            "initialLatitude": root.initialLatitude,
            "initialLongitude": root.initialLongitude,
            "initialZoom": root.fitInitialRadius ? 10 : 4,
            "fitInitialRadius": root.fitInitialRadius,
            "radiusMode": root.fitInitialRadius,
            "tileCacheDirectory": mapbox ? root.builder.mapCacheDirectory("preview_mapbox") : root.builder.previewCacheDirectory,
            "tileHost": mapbox ? root.builder.mapboxBaseUrl : "https://tile.openstreetmap.org/",
            "usingMapbox": mapbox
        })
        canvas.active = true
    }
    onMapboxApiKeyChanged: if (!opened) canvas.active = false

    contentItem: Rectangle {
        objectName: "offlineMapDialogContent"
        color: root.panelColor
        ColumnLayout {
        anchors.fill: parent
        spacing: 5
        Label { text: qsTr("Create an offline map"); color: root.textColor; font.bold: true; font.pixelSize: 20 }
        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: region
                objectName: "offlineRegionSearch"
                Layout.fillWidth: true
                placeholderText: qsTr("Town or region")
                enabled: !!root.builder && !root.working
                selectByMouse: true
                onAccepted: root.builder.search(text)
            }
            OfflineMapButton {
                text: root.builder && root.builder.searching ? qsTr("Searching...") : qsTr("Find region")
                enabled: !!root.builder && region.text.trim().length > 0 && !root.working
                onClicked: root.builder.search(region.text)
            }
        }
        ComboBox {
            id: results
            Layout.fillWidth: true
            visible: count > 0
            model: root.builder ? root.builder.searchResults : []
            textRole: "name"
            enabled: !root.working
            displayText: currentIndex >= 0 ? currentText : qsTr("Choose a region")
            onActivated: {
                if (canvas.item) canvas.item.fitRegion(model[index])
                region.text = model[index].name.split(",")[0]
            }
            onCountChanged: {
                currentIndex = -1
                if (count === 1 && canvas.item) {
                    currentIndex = 0
                    activated(0)
                }
            }
        }
        Loader {
            id: canvas
            objectName: "offlineMapCanvas"
            enabled: !root.working
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.minimumHeight: 120
            active: false
        }
        Label {
            visible: canvas.status === Loader.Error || !!(canvas.item && canvas.item.mapError)
            text: canvas.status === Loader.Error ? qsTr("Map preview is unavailable. Install the Qt Location and Positioning modules.")
                  : canvas.item ? canvas.item.mapError : ""
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: root.textColor
        }
        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            spacing: 8
            OfflineMapButton {
                objectName: "drawOfflineRectangle"
                text: canvas.item && canvas.item.drawing ? qsTr("Cancel drawing") : qsTr("Draw rectangle")
                enabled: !!canvas.item && canvas.item.ready && !root.working
                onClicked: {
                    if (canvas.item.drawing) canvas.item.drawing = false
                    else canvas.item.startRectangle()
                }
            }
            OfflineMapButton {
                objectName: "selectRadius"
                text: qsTr("50 km radius")
                enabled: !!canvas.item && canvas.item.ready && !root.working
                onClicked: canvas.item.selectCenterRadius()
            }
            OfflineMapButton {
                text: qsTr("Clear area")
                enabled: !!canvas.item && canvas.item.selectionValid && !root.working
                onClicked: canvas.item.clearSelection()
            }
        }
        Label {
            id: estimate
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: root.textColor
            visible: canvas.status !== Loader.Error && !(canvas.item && canvas.item.mapError)
            text: !canvas.item || !canvas.item.ready ? qsTr("Loading map preview…")
                  : canvas.item.drawing ? (canvas.item.drawingError || qsTr("Drag across the map to outline the area."))
                  : canvas.item.selectionValid ? qsTr("Selected area: %1 × %2 km")
                        .arg(canvas.item.areaWidthKm.toFixed(1)).arg(canvas.item.areaHeightKm.toFixed(1))
                  : qsTr("Find a place or pan and zoom, then select Draw rectangle.")
        }
        Label {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: root.textColor
            visible: text.length > 0
            text: root.generationStatus && !(root.builder && root.builder.searching) ? root.generationStatus
                  : root.builder ? root.builder.status : ""
        }
        ProgressBar {
            objectName: "offlineMapProgress"
            Layout.fillWidth: true
            visible: root.working
            indeterminate: true
        }
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                color: root.textColor
                wrapMode: Text.WordWrap
                text: qsTr("Smaller areas include more street detail.")
            }
            OfflineMapButton {
                objectName: "cancelOfflineMap"
                visible: !root.downloadId
                text: root.working ? qsTr("Cancel") : qsTr("Close")
                onClicked: {
                    if (root.generationRequest) root.stopGeneration(qsTr("Canceled."))
                    else if (root.working) root.builder.cancel()
                    else root.close()
                }
            }
            OfflineMapButton {
                objectName: "createOfflineMap"
                primary: true
                text: qsTr("Create map")
                enabled: !!canvas.item && canvas.item.ready && canvas.item.selectionValid && !canvas.item.drawing && !root.working
                onClicked: root.generateRegion()
            }
        }
    }
    }
}
