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
    readonly property string stagedMap: mainWindow ? mainWindow.localOfflineMapPath : ""
    readonly property bool busy: catalog ? catalog.busy : false
    readonly property bool accountConnected: mainWindow && mainWindow.fleetControlSignedIn === true
    property string tokenStatus: ""
    property bool tokenRequestPending: false
    property string localPreviewToken: imageWriter.getValue("localMapboxPreviewToken") || ""
    property var previewBuilder: typeof _offlineMapBuilder === "undefined" ? null : _offlineMapBuilder

    onVisibleChanged: if (visible && catalog && !catalog.regions.length) catalog.refresh()
    Component.onCompleted: if (visible && catalog && !catalog.regions.length) catalog.refresh()

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

    Material.theme: Material.Dark
    Material.accent: "#278cff"

    Connections {
        target: root.catalog
        function onSelected(filePath) {
            imageWriter.setSetting("offlineMapCreatorPackagePath", filePath)
        }
    }

    Dialogs.FileDialog {
        id: archiveDialog
        title: qsTr("Choose a vector map")
        nameFilters: [qsTr("vector maps (*.mbtiles)")]
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
                    text: qsTr("Download a regional map or choose a vector MBTiles file. ImageWriter includes the selected map when you flash a Ground image.")
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
                        visible: !!root.catalog && !root.busy && !region.count
                        text: qsTr("Reload regions")
                        onClicked: root.catalog.refresh()
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
                        onClicked: archiveDialog.open()
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
                    text: qsTr("Regional maps by Librescoot · Map data © OpenStreetMap contributors")
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
