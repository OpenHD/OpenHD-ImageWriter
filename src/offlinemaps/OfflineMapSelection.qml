import QtQuick 2.12
import QtLocation 5.15
import QtPositioning 5.15

Item {
    id: root
    property real initialLatitude: 0
    property real initialLongitude: 0
    property string tileCacheDirectory: ""
    property string tileHost: "https://tile.openstreetmap.org/"
    property bool usingMapbox: false
    property bool drawing: false
    property bool radiusMode: true
    property int radiusMeters: 50000
    property real initialZoom: 10
    property bool fitInitialRadius: true
    readonly property bool ready: map.mapReady
    readonly property string mapError: map.errorString
    property var radiusCenter: QtPositioning.coordinate(initialLatitude, initialLongitude)
    function selectRadius(coordinate) {
        if (!coordinate || !coordinate.isValid) return
        drawing = false
        radiusCenter = coordinate
        var angular = radiusMeters / 6371007.2
        var latitude = coordinate.latitude * Math.PI / 180
        var deltaLon = Math.asin(Math.sin(angular) / Math.cos(latitude)) * 180 / Math.PI
        south = coordinate.latitude - angular * 180 / Math.PI
        north = coordinate.latitude + angular * 180 / Math.PI
        west = coordinate.longitude - deltaLon
        east = coordinate.longitude + deltaLon
        selectionValid = isFinite(deltaLon) && south >= -85 && north <= 85 && west >= -180 && east <= 180
    }
    function selectCenterRadius() {
        radiusMode = true
        selectRadius(map.center)
        if (selectionValid)
            map.visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(north, west),
                                                       QtPositioning.coordinate(south, east))
    }
    property bool selectionValid: false
    property real south: 0
    property real west: 0
    property real north: 0
    property real east: 0
    readonly property real areaWidthKm: (east - west) * 111.2 * Math.cos((north + south) * Math.PI / 360)
    readonly property real areaHeightKm: (north - south) * 111.2

    function startRectangle() {
        if (!ready) return
        drawing = true
    }

    function clearSelection() {
        drawing = false
        selectionValid = false
    }

    function fitRegion(region) {
        clearSelection()
        map.visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(region.north, region.west),
                                                   QtPositioning.coordinate(region.south, region.east))
        if (radiusMode) {
            selectRadius(QtPositioning.coordinate((Number(region.north) + Number(region.south)) / 2,
                                                  (Number(region.west) + Number(region.east)) / 2))
            map.visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(north, west), QtPositioning.coordinate(south, east))
        }
    }
    Component.onCompleted: if (fitInitialRadius) selectRadius(radiusCenter)
    onRadiusMetersChanged: {
        if (!radiusMode) return
        selectRadius(radiusCenter)
        if (map && map.mapReady && selectionValid)
            map.visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(north, west),
                                                       QtPositioning.coordinate(south, east))
    }
    onInitialLatitudeChanged: map.center = QtPositioning.coordinate(initialLatitude, initialLongitude)
    onInitialLongitudeChanged: map.center = QtPositioning.coordinate(initialLatitude, initialLongitude)

    Plugin {
        id: osm
        name: "osm"
        PluginParameter { name: "osm.useragent"; value: "OpenHD-ImageWriter/1.0 (+https://openhd.tech)" }
        PluginParameter { name: "osm.mapping.cache.directory"; value: root.tileCacheDirectory }
        PluginParameter { name: "osm.mapping.prefetching_style"; value: "NoPrefetching" }
        PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: true }
        PluginParameter { name: "osm.mapping.custom.host"; value: root.tileHost }
        PluginParameter {
            name: "osm.mapping.custom.mapcopyright"
            value: root.usingMapbox
                ? '<a href="https://www.mapbox.com/about/maps/">© Mapbox</a> <a href="https://www.openstreetmap.org/copyright">© OpenStreetMap</a> <a href="https://apps.mapbox.com/feedback/">Improve this map</a>'
                : "© OpenStreetMap contributors"
        }
    }
    Map {
        id: map
        objectName: "offlineSelectionMap"
        anchors.fill: parent
        plugin: osm
        center: QtPositioning.coordinate(root.initialLatitude, root.initialLongitude)
        zoomLevel: root.initialZoom
        copyrightsVisible: true
        function useCustomMapType() {
            for (var i = 0; i < supportedMapTypes.length; ++i) {
                if (supportedMapTypes[i].style === MapType.CustomMap) {
                    activeMapType = supportedMapTypes[i]
                    return
                }
            }
        }
        Component.onCompleted: useCustomMapType()
        onMapReadyChanged: {
            if (mapReady && root.fitInitialRadius && root.radiusMode && root.selectionValid)
                visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(root.north, root.west),
                                                       QtPositioning.coordinate(root.south, root.east))
        }
        gesture.enabled: !root.drawing
        gesture.acceptedGestures: MapGestureArea.PanGesture | MapGestureArea.FlickGesture | MapGestureArea.PinchGesture
        onSupportedMapTypesChanged: useCustomMapType()
        MapCircle {
            visible: root.selectionValid && root.radiusMode && !rectangleInput.pressed
            center: root.radiusCenter
            radius: root.radiusMeters
            color: "#4030a8ff"
            border.color: "#30a8ff"; border.width: 2
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.ready && root.radiusMode && !root.drawing
            onClicked: root.selectRadius(map.toCoordinate(Qt.point(mouse.x, mouse.y), false))
        }
        MapRectangle {
            visible: root.selectionValid && !root.radiusMode && !rectangleInput.pressed
            topLeft: QtPositioning.coordinate(root.north, root.west)
            bottomRight: QtPositioning.coordinate(root.south, root.east)
            color: "#4030a8ff"
            border.color: "#30a8ff"; border.width: 2
        }
    }
    Image {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 8
        width: 88; height: 23; fillMode: Image.PreserveAspectFit
        visible: root.usingMapbox
        source: root.usingMapbox ? "MapboxLogo.png" : ""
    }
    MouseArea {
        id: rectangleInput
        anchors.fill: parent
        objectName: "offlineRectangleInput"
        enabled: root.ready && root.drawing
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.CrossCursor : Qt.ArrowCursor
        preventStealing: true
        property point origin
        readonly property real endX: Math.max(0, Math.min(width - 1, mouseX))
        readonly property real endY: Math.max(0, Math.min(height - 1, mouseY))
        property string error: ""

        onEnabledChanged: if (enabled) error = ""
        onPressed: {
            error = ""
            origin = Qt.point(mouse.x, mouse.y)
        }
        onReleased: {
            if (outline.width < 4 || outline.height < 4) {
                error = qsTr("Drag across the map to draw a rectangle.")
                return
            }
            var topLeft = map.toCoordinate(Qt.point(outline.x, outline.y), false)
            var bottomRight = map.toCoordinate(Qt.point(outline.x + outline.width, outline.y + outline.height), false)
            if (!topLeft.isValid || !bottomRight.isValid || topLeft.longitude >= bottomRight.longitude
                    || bottomRight.longitude - topLeft.longitude >= 180
                    || bottomRight.latitude >= topLeft.latitude
                    || topLeft.latitude > 85 || bottomRight.latitude < -85) {
                error = qsTr("Draw a smaller area away from the poles and the date line.")
                return
            }
            root.south = bottomRight.latitude
            root.north = topLeft.latitude
            root.west = topLeft.longitude
            root.east = bottomRight.longitude
            root.radiusMode = false
            root.selectionValid = true
            root.drawing = false
        }
        Rectangle {
            id: outline
            visible: rectangleInput.pressed
            x: Math.min(rectangleInput.origin.x, rectangleInput.endX)
            y: Math.min(rectangleInput.origin.y, rectangleInput.endY)
            width: Math.abs(rectangleInput.origin.x - rectangleInput.endX)
            height: Math.abs(rectangleInput.origin.y - rectangleInput.endY)
            color: "#4030a8ff"
            border.color: "#30a8ff"
            border.width: 2
        }
    }
    readonly property string drawingError: drawing ? rectangleInput.error : ""
    Column {
        enabled: root.ready
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
        spacing: 4
        Rectangle {
            width: 40; height: 40; color: "#182732"; radius: 4
            Text { anchors.centerIn: parent; text: "+"; color: "white"; font.pixelSize: 24 }
            MouseArea { anchors.fill: parent; onClicked: map.zoomLevel = Math.min(18, map.zoomLevel + 1) }
        }
        Rectangle {
            width: 40; height: 40; color: "#182732"; radius: 4
            Text { anchors.centerIn: parent; text: "−"; color: "white"; font.pixelSize: 24 }
            MouseArea { anchors.fill: parent; onClicked: map.zoomLevel = Math.max(3, map.zoomLevel - 1) }
        }
    }
}
