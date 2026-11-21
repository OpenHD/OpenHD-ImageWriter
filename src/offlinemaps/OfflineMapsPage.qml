import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Controls.Material 2.12
import QtQuick.Dialogs 1.3 as Dialogs
import QtQuick.Layouts 1.12

Item {
    id: root
    objectName: "offlineMapsPage"
    property var mainWindow
    property var catalog: typeof _vectorMapCatalog === "undefined" ? null : _vectorMapCatalog
    property var builder: typeof _styledOfflineMapBuilder === "undefined" ? null : _styledOfflineMapBuilder
    readonly property var radii: [5, 10, 25, 50]
    readonly property string stagedMap: mainWindow ? mainWindow.localOfflineMapPath : ""
    readonly property bool busy: (catalog && catalog.busy) || (builder && (builder.busy || builder.searching))
    readonly property int tileCount: builder && picker.item && picker.item.selectionValid
        ? builder.tileCount(picker.item.south, picker.item.west, picker.item.north,
                            picker.item.east, 13 + detail.currentIndex) : 0
    readonly property bool accountConnected: mainWindow && mainWindow.fleetControlSignedIn === true
    property string tokenStatus: ""
    property bool tokenRequestPending: false
    property string localPreviewToken: imageWriter.getValue("localMapboxPreviewToken") || ""
    property var previewBuilder: typeof _offlineMapBuilder === "undefined" ? null : _offlineMapBuilder

    function syncToken(save) {
        if (!accountConnected || tokenRequestPending) return
        var token = tokenField.text.trim()
        var request = new XMLHttpRequest()
        tokenRequestPending = true
        request.open(save ? "PUT" : "GET", "https://openhd.tech/api/account/mapbox-token")
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            tokenRequestPending = false
            if (request.status !== 200 || !root.accountConnected) {
                tokenStatus = qsTr("Could not sync the Mapbox token with FleetControl.")
                return
            }
            if (save) {
                tokenStatus = token.length ? qsTr("Mapbox token saved to your account.") : qsTr("Mapbox token removed from your account.")
            } else {
                try {
                    var accountToken = JSON.parse(request.responseText).token
                    if (typeof accountToken !== "string") throw new Error()
                    if (accountToken.length) {
                        tokenField.text = accountToken
                        root.saveLocalToken()
                    }
                    tokenStatus = accountToken.length ? qsTr("Mapbox token restored on this computer.")
                                                      : qsTr("This account has no saved Mapbox token.")
                } catch (error) {
                    tokenStatus = qsTr("FleetControl returned an invalid response.")
                }
            }
        }
        if (save) request.setRequestHeader("Content-Type", "application/json")
        request.send(save ? JSON.stringify({token: token}) : null)
    }

    function saveLocalToken() {
        var token = tokenField.text.trim()
        if (token.length && !/^pk\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)) {
            tokenStatus = qsTr("Enter a public Mapbox token.")
            return
        }
        imageWriter.setSetting("localMapboxPreviewToken", token)
        localPreviewToken = token
        if (previewBuilder) previewBuilder.setMapboxKey(token)
        tokenStatus = token.length ? qsTr("Mapbox token saved on this computer.") : qsTr("Local Mapbox token removed.")
    }

    function loadPicker() {
        if (!picker.active && builder) {
            picker.setSource("OfflineMapSelection.qml", {
                tileCacheDirectory: builder.previewCacheDirectory,
                radiusMeters: radii[radius.currentIndex] * 1000,
                initialZoom: 3,
                fitInitialRadius: false
            })
            picker.active = true
        }
    }

    function selectSearchResult(index) {
        if (!picker.item || !builder || index < 0) return
        var result = builder.searchResults[index]
        picker.item.fitRegion(result)
        place.text = result.name.split(",")[0]
    }

    function createStyledMap(archive) {
        if (!builder || tileCount <= 0 || builder.busy || builder.searching) return
        builder.generateStyled(archive, place.text, picker.item.south, picker.item.west,
                               picker.item.north, picker.item.east, 13 + detail.currentIndex)
    }

    onVisibleChanged: if (visible) loadPicker()
    Component.onCompleted: if (visible) loadPicker()

    Material.theme: Material.Dark
    Material.accent: "#278cff"

    Connections {
        target: root.catalog
        function onSelected(filePath) {
            imageWriter.setSetting("offlineMapCreatorPackagePath", filePath)
        }
    }

    Connections {
        target: root.builder
        function onGenerated(filePath) {
            imageWriter.setSetting("offlineMapCreatorPackagePath", filePath)
        }
    }

    Dialogs.FileDialog {
        id: archiveDialog
        title: qsTr("Choose a Shortbread vector map to add to the selected area")
        nameFilters: [qsTr("Shortbread vector maps (*.mbtiles)")]
        onAccepted: root.createStyledMap(fileUrl)
    }

    Dialogs.FileDialog {
        id: catalogFileDialog
        title: qsTr("Choose a Shortbread vector map")
        nameFilters: [qsTr("Shortbread vector maps (*.mbtiles)")]
        onAccepted: root.catalog.selectFile(fileUrl)
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scroll.availableWidth

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 24
                spacing: 12

                Label {
                    text: qsTr("Offline maps")
                    font.pixelSize: 28
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Download a regional map or choose a Shortbread MBTiles file. ImageWriter includes the selected map when you flash a Ground image.")
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    ComboBox {
                        id: region
                        objectName: "offlineMapRegion"
                        Layout.fillWidth: true
                        model: root.catalog ? root.catalog.regions : []
                        enabled: !!root.catalog && !root.busy
                    }
                    OfflineMapButton {
                        objectName: "downloadVectorMap"
                        text: qsTr("Download map")
                        primary: true
                        enabled: !!root.catalog && !root.busy && region.currentIndex >= 0
                        onClicked: root.catalog.download(region.currentIndex)
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    spacing: 8
                    OfflineMapButton {
                        objectName: "importVectorMap"
                        text: qsTr("Choose MBTiles file…")
                        enabled: !!root.catalog && !root.busy
                        onClicked: catalogFileDialog.open()
                    }
                    OfflineMapButton {
                        objectName: "cancelVectorMap"
                        text: qsTr("Cancel")
                        visible: root.busy
                        onClicked: root.catalog.cancel()
                    }
                }
                ProgressBar {
                    Layout.fillWidth: true
                    visible: root.busy
                    value: root.catalog ? root.catalog.progress : 0
                    indeterminate: value === 0
                }
                Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.catalog ? root.catalog.status : ""
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#355362"
                }
                Label {
                    text: qsTr("Create an offline map")
                    font.pixelSize: 22
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Search for a place, choose a circular radius or draw an area, then create an offline map for QOpenHD.")
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: place
                        objectName: "styledMapPlaceSearch"
                        Layout.fillWidth: true
                        placeholderText: qsTr("Town or region")
                        selectByMouse: true
                        enabled: !!root.builder && !root.busy
                        onAccepted: if (text.trim().length) root.builder.search(text)
                    }
                    OfflineMapButton {
                        text: root.builder && root.builder.searching ? qsTr("Searching…") : qsTr("Find")
                        enabled: !!root.builder && place.text.trim().length > 0 && !root.busy
                        onClicked: root.builder.search(place.text)
                    }
                }
                ComboBox {
                    Layout.fillWidth: true
                    visible: count > 0
                    enabled: !root.busy
                    model: root.builder ? root.builder.searchResults : []
                    textRole: "name"
                    displayText: currentIndex >= 0 ? currentText : qsTr("Choose a result")
                    onActivated: root.selectSearchResult(index)
                    onCountChanged: {
                        currentIndex = count === 1 ? 0 : -1
                        if (count === 1) root.selectSearchResult(0)
                    }
                }
                Loader {
                    id: picker
                    objectName: "styledMapSelection"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(250, Math.min(440, root.height - 370))
                    enabled: !root.busy
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
                    columns: width < 560 ? 2 : 4
                    enabled: !root.busy && !!picker.item
                    OfflineMapButton {
                        objectName: "selectStyledMapCircle"
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
                        enabled: !!picker.item && picker.item.radiusMode && !root.busy
                        onActivated: picker.item.radiusMeters = root.radii[index] * 1000
                    }
                    ComboBox {
                        id: detail
                        Layout.fillWidth: true
                        model: [qsTr("Overview"), qsTr("Standard detail"), qsTr("High detail"), qsTr("Maximum detail")]
                        currentIndex: 1
                        enabled: !root.busy
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: root.tileCount < 0 ? qsTr("Choose a smaller area or lower detail.")
                            : root.tileCount > 0 ? qsTr("%1 tiles").arg(root.tileCount) : qsTr("Select an area")
                    }
                    OfflineMapButton {
                        objectName: "cancelStyledMap"
                        text: qsTr("Cancel")
                        visible: root.builder && (root.builder.busy || root.builder.searching)
                        onClicked: root.builder.cancel()
                    }
                    OfflineMapButton {
                        text: qsTr("Use MBTiles…")
                        enabled: root.tileCount > 0 && !root.busy
                        onClicked: archiveDialog.open()
                    }
                    OfflineMapButton {
                        objectName: "createStyledMap"
                        text: qsTr("Create map")
                        primary: true
                        enabled: root.tileCount > 0 && !root.busy
                        onClicked: root.createStyledMap("")
                    }
                }
                Label {
                    Layout.fillWidth: true
                    visible: !!root.builder && root.builder.status.length > 0
                    text: root.builder ? root.builder.status : ""
                    wrapMode: Text.WordWrap
                }
                ProgressBar {
                    Layout.fillWidth: true
                    visible: root.builder && (root.builder.busy || root.builder.searching)
                    value: root.builder ? root.builder.progress : 0
                    indeterminate: root.builder && (root.builder.searching || root.builder.progress === 0)
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.stagedMap.length > 0
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        text: qsTr("Included on Ground flashes: %1").arg(root.stagedMap.split(/[\\/]/).pop())
                    }
                    OfflineMapButton {
                        text: qsTr("Remove")
                        enabled: !root.busy
                        onClicked: imageWriter.setSetting("offlineMapCreatorPackagePath", "")
                    }
                }
                Label {
                    text: qsTr("Regional downloads by Geofabrik · Map data © OpenStreetMap contributors")
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                Label { text: qsTr("Mapbox preview token"); font.bold: true }
                TextField {
                    id: tokenField
                    Layout.fillWidth: true
                    maximumLength: 1024
                    echoMode: TextInput.Password
                    placeholderText: qsTr("Public Mapbox token")
                    text: root.localPreviewToken
                    onAccepted: root.saveLocalToken()
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    spacing: 8
                    OfflineMapButton { text: qsTr("Save on this computer"); onClicked: root.saveLocalToken() }
                    OfflineMapButton {
                        text: preview.active ? qsTr("Close preview") : qsTr("Preview Mapbox")
                        visible: !!root.previewBuilder && root.localPreviewToken.length > 0
                        onClicked: {
                            if (preview.active) {
                                preview.active = false
                                return
                            }
                            root.previewBuilder.setMapboxKey(root.localPreviewToken)
                            preview.setSource("OfflineMapSelection.qml", {
                                usingMapbox: true,
                                tileCacheDirectory: root.previewBuilder.mapCacheDirectory("preview_mapbox"),
                                tileHost: root.previewBuilder.mapboxBaseUrl,
                                fitInitialRadius: false
                            })
                            preview.active = true
                        }
                    }
                    OfflineMapButton {
                        text: qsTr("Save to FleetControl")
                        visible: root.accountConnected
                        enabled: !root.tokenRequestPending
                        onClicked: root.syncToken(true)
                    }
                    OfflineMapButton {
                        text: qsTr("Restore from FleetControl")
                        visible: root.accountConnected
                        enabled: !root.tokenRequestPending
                        onClicked: root.syncToken(false)
                    }
                }
                Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.tokenStatus
                    wrapMode: Text.WordWrap
                }
                Loader {
                    id: preview
                    Layout.fillWidth: true
                    Layout.preferredHeight: 290
                    active: false
                    visible: active && root.localPreviewToken.length > 0
                }
            }
        }
    }
}
