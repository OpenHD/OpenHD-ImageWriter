import QtQuick 2.9
import QtQuick.Controls 2.2

Item {
    id: root

    property var sourceModel: null
    property bool rootLevel: true
    property int activeTab: 0
    property bool includeDevelopment: false
    property bool catalogLoading: false
    property int mainItemCount: 0
    property int sourceCount: 0
    property bool developerLoading: false
    property string developerError: ""
    property string developerApi: ""
    property int pageIndex: 0
    property int cacheRevision: 0

    signal itemSelected(var item)

    Connections {
        target: typeof imageWriter !== "undefined" ? imageWriter : null
        onCacheChanged: root.cacheRevision++
    }

    readonly property var displayEntries: buildDisplayEntries(activeTab, mainItemCount,
                                                               rootLevel, sourceModel,
                                                               includeDevelopment, sourceCount)
    readonly property int pageCount: Math.max(1, Math.ceil(displayEntries.length / 6))
    readonly property bool paged: displayEntries.length > 6
    readonly property real gridWidth: width - (paged ? 46 : 0)
    readonly property int visibleCardCount: Math.min(6, Math.max(0,
        displayEntries.length - pageIndex * 6))
    readonly property int responsiveColumns: gridWidth >= 640 ? 3
                                                    : (gridWidth >= 420 ? 2 : 1)
    readonly property int contentColumns: visibleCardCount <= 2
                                          ? Math.max(1, visibleCardCount)
                                          : (visibleCardCount <= 4 ? 2 : 3)
    readonly property int columnCount: Math.min(responsiveColumns, contentColumns)
    readonly property real cardWidth: (gridWidth - ((columnCount - 1) * 10)) / columnCount
    readonly property real cardHeight: visibleCardCount <= 2 && gridWidth >= 600 ? 220
                                       : (visibleCardCount < 6 && gridWidth >= 420 ? 194 : 174)
    readonly property real logoSize: cardHeight >= 210 ? 72
                                     : (cardHeight >= 190 ? 64 : 58)
    readonly property int platformRowCount: Math.ceil(6 / responsiveColumns)
    readonly property real platformGridHeight:
        platformRowCount * 174 + (platformRowCount - 1) * 10
    readonly property real naturalHeight: content.implicitHeight + 4

    onActiveTabChanged: pageIndex = 0
    onRootLevelChanged: pageIndex = 0
    // A changed result set should always start on its first page. Avoid
    // reading pageCount here: its binding depends on displayEntries and doing
    // so from this change handler creates a binding cycle in Qt 5.
    onDisplayEntriesChanged: pageIndex = 0

    function itemAt(displayIndex) {
        return sourceModel ? sourceModel.get(displayIndex + (rootLevel ? 0 : 1)) : null
    }

    function utilityAt(offsetFromEnd) {
        return sourceModel ? sourceModel.get(sourceCount - offsetFromEnd) : null
    }

    function copyEntry(source) {
        var copy = {}
        for (var key in source)
            copy[key] = source[key]
        return copy
    }

    function resolvedIcon(entry) {
        var icon = entry ? String(entry.icon || "") : ""
        if (icon.indexOf("icons/") === 0)
            return "../" + icon
        return icon.length > 0 ? icon : "../icons/manufacturers/more-mono.svg"
    }

    function isDownloadEntry(entry) {
        if (!entry)
            return false
        var url = String(entry.url || "")
        return url.length > 0 && url.indexOf("internal://") !== 0
    }

    function formatFileSize(bytes) {
        var size = Number(bytes || 0)
        if (!isFinite(size) || size <= 0)
            return qsTr("Size unavailable")

        var units = [qsTr("B"), qsTr("KB"), qsTr("MB"), qsTr("GB"), qsTr("TB")]
        var unit = 0
        while (size >= 1024 && unit < units.length - 1) {
            size /= 1024
            unit++
        }
        var precision = size >= 100 || unit === 0 ? 0 : 1
        return size.toFixed(precision) + " " + units[unit]
    }

    function secondaryText(entry) {
        return isDownloadEntry(entry)
                ? formatFileSize(entry.image_download_size)
                : String(entry ? entry.description || "" : "")
    }

    function isEntryCached(entry) {
        // Keep this binding dependent on cacheRevision so it refreshes after a write.
        var revision = cacheRevision
        if (!isDownloadEntry(entry) || typeof imageWriter === "undefined")
            return false
        return imageWriter.isCached(String(entry.url || ""),
                                    String(entry.extract_sha256 || ""))
    }

    function isDeveloper(entry) {
        if (!entry)
            return false
        if (String(entry.channel || "").toLowerCase() === "development")
            return true
        var text = ((entry.name || "") + " " + (entry.description || "")).toLowerCase()
        return text.indexOf("beta") >= 0 || text.indexOf("nightly") >= 0 ||
               text.indexOf("dev") >= 0 || text.indexOf("snapshot") >= 0
    }

    function isFleetControl(entry) {
        if (!entry)
            return false
        var url = String(entry.url || "")
        return String(entry.catalog_source || "") === "fleetcontrol" ||
               url.indexOf(developerApi) === 0 ||
               url.indexOf("https://dl.cloudsmith.io/public/openhd/") === 0
    }

    function platformDefinitions() {
        return [
            {
                key: "openhd",
                name: qsTr("OpenHD Hardware"),
                description: qsTr("X20 and X21"),
                icon: "icons/manufacturers/openhd-mono.svg"
            },
            {
                key: "raspberry-pi",
                name: qsTr("Raspberry Pi"),
                description: qsTr("Pi 2–5 and Compute Modules"),
                icon: "icons/manufacturers/raspberrypi-mono.svg"
            },
            {
                key: "radxa",
                name: qsTr("Radxa"),
                description: qsTr("ROCK 3, ROCK 5, CM3 and Cubie A7"),
                icon: "icons/manufacturers/radxa-mono.svg"
            },
            {
                key: "luckfox",
                name: qsTr("Luckfox"),
                description: qsTr("Aura, Pico and Lyra"),
                icon: "icons/manufacturers/luckfox-mono.svg"
            },
            {
                key: "x86",
                name: qsTr("x86 / PC"),
                description: qsTr("Intel and AMD systems"),
                icon: "icons/manufacturers/x86-mono.svg"
            },
            {
                key: "rest",
                name: qsTr("More"),
                description: qsTr("Orange Pi, Orqa and more"),
                icon: "icons/manufacturers/more-mono.svg"
            }
        ]
    }

    function buildPlatformCards(tab, count, model, allowDevelopment) {
        var definitions = platformDefinitions()
        var buckets = {
            "openhd": [],
            "raspberry-pi": [],
            "luckfox": [],
            "radxa": [],
            "x86": [],
            "rest": []
        }

        for (var i = 0; i < count; ++i) {
            var group = model ? model.get(i) : null
            if (!group)
                continue
            var developer = isDeveloper(group) || isFleetControl(group)
            if ((tab === 0 && developer) ||
                    (tab === 1 && (!allowDevelopment || !developer)))
                continue

            var manufacturer = String(group.manufacturer || "other")
            var bucket = buckets[manufacturer] ? manufacturer : "rest"
            if (bucket === "rest") {
                buckets.rest.push(copyEntry(group))
                continue
            }

            var boards = []
            try {
                boards = JSON.parse(String(group.subitems_json || "[]"))
            } catch (error) {
                boards = []
            }
            for (var boardIndex = 0; boardIndex < boards.length; ++boardIndex)
                buckets[bucket].push(boards[boardIndex])
        }

        var cards = []
        for (var definitionIndex = 0; definitionIndex < definitions.length; ++definitionIndex) {
            var definition = definitions[definitionIndex]
            var children = buckets[definition.key]
            cards.push({
                name: definition.name,
                description: children.length > 0
                             ? definition.description
                             : qsTr("No images available yet"),
                icon: definition.icon,
                url: "",
                channel: tab === 1 ? "development" : "stable",
                manufacturer: definition.key,
                subitems_json: JSON.stringify(children)
            })
        }
        return cards
    }

    function buildDisplayEntries(tab, count, atRoot, model, allowDevelopment, totalCount) {
        var entries = []
        if (atRoot && tab === 2) {
            if (model && totalCount >= 2) {
                var custom = copyEntry(model.get(totalCount - 1))
                custom.name = qsTr("Use custom image")
                custom.description = qsTr("Choose an image file from this computer")
                custom.icon = "icons/ui/custom-image-folder-file.svg"
                entries.push(custom)

                var erase = copyEntry(model.get(totalCount - 2))
                erase.name = qsTr("Erase / Format")
                erase.icon = "icons/ui/erase-format-trash.svg"
                entries.push(erase)
            }
            return entries
        }

        if (atRoot)
            return buildPlatformCards(tab, count, model, allowDevelopment)

        for (var i = 0; i < count; ++i) {
            var entry = model ? model.get(i + (atRoot ? 0 : 1)) : null
            if (!entry)
                continue
            entries.push(entry)
        }
        return entries
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + 4
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: content.implicitHeight > scroll.height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Column {
            id: content
            width: scroll.width
            spacing: 10

            Item {
                width: parent.width
                height: visible ? 54 : 0
                visible: root.rootLevel && root.activeTab === 1 &&
                         root.developerError.length > 0

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.developerError
                        color: "#efad73"
                        font.pixelSize: 12
                    }
                }
            }

            Item {
                width: parent.width
                height: visible ? 70 : 0
                visible: root.displayEntries.length === 0 &&
                         !(root.rootLevel && root.activeTab === 0 && root.catalogLoading) &&
                         !(root.rootLevel && root.activeTab === 1 && root.developerLoading)

                Text {
                    anchors.centerIn: parent
                    text: qsTr("No images are available for this hardware family yet.")
                    color: "#7895a5"
                    font.pixelSize: 12
                }
            }

            Item {
                id: pagedCards
                width: parent.width
                height: cardFlow.implicitHeight

                Flow {
                    id: cardFlow
                    anchors.left: parent.left
                    width: root.gridWidth
                    spacing: 10

                    Repeater {
                        model: root.displayEntries

                        delegate: Item {
                            id: cardContainer
                            property var entry: modelData
                            readonly property bool cached: root.isEntryCached(entry)
                            readonly property bool shown:
                                index >= root.pageIndex * 6 && index < (root.pageIndex + 1) * 6

                            visible: shown
                            width: shown ? root.cardWidth : 0
                            height: shown ? root.cardHeight : 0

                            Button {
                                id: cardButton
                                anchors.fill: parent
                                padding: 0
                                hoverEnabled: true

                                background: Rectangle {
                                    radius: 10
                                    color: cardButton.down ? "#15374b"
                                          : cardButton.hovered ? "#102f42" : "#0e2635"
                                    border.width: 1
                                    border.color: cardButton.hovered ? "#2c7498" : "#1b4b64"

                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Behavior on border.color { ColorAnimation { duration: 80 } }
                                }

                                contentItem: Item {
                                    Image {
                                        id: brandLogo
                                        anchors.top: parent.top
                                        anchors.topMargin: 14
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: root.logoSize
                                        height: root.logoSize
                                        sourceSize.width: root.logoSize * 2
                                        sourceSize.height: root.logoSize * 2
                                        source: root.resolvedIcon(cardContainer.entry)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        antialiasing: true
                                    }

                                    Column {
                                        anchors.top: brandLogo.bottom
                                        anchors.topMargin: 7
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 2

                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: cardContainer.entry ? cardContainer.entry.name : ""
                                            color: "#f5f8fa"
                                            font.pixelSize: root.cardHeight >= 210 ? 16 : 14
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }

                                        Item {
                                            width: parent.width
                                            height: metadataRow.implicitHeight

                                            Row {
                                                id: metadataRow
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 6

                                                Text {
                                                    width: Math.min(implicitWidth,
                                                                    parent.parent.width -
                                                                    (cacheBadge.visible ? 22 : 0))
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: root.secondaryText(cardContainer.entry)
                                                    color: "#8eabba"
                                                    font.pixelSize: root.cardHeight >= 190 ? 12 : 11
                                                    elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    id: cacheBadge
                                                    width: visible ? 16 : 0
                                                    height: 16
                                                    radius: 8
                                                    visible: cardContainer.cached
                                                    color: "#168df3"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "✓"
                                                        color: "#ffffff"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        id: cacheBadgeMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        acceptedButtons: Qt.NoButton
                                                    }

                                                    ToolTip.visible: cacheBadgeMouse.containsMouse
                                                    ToolTip.text: qsTr("Already downloaded and cached")
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 10
                                        height: 30
                                        radius: 15
                                        color: cardButton.hovered ? "#13527a" : "#103b55"
                                        border.width: 1
                                        border.color: "#175575"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "→"
                                            color: "#d9e8ef"
                                            font.pixelSize: 19
                                            font.weight: Font.Light
                                        }
                                    }
                                }

                                onClicked: {
                                    if (cardContainer.entry)
                                        root.itemSelected(cardContainer.entry)
                                }
                            }
                        }
                    }
                }

                Button {
                    id: pageArrow
                    anchors.top: cardFlow.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: root.paged ? 36 : 0
                    visible: root.paged
                    padding: 0
                    hoverEnabled: true

                    background: Rectangle {
                        radius: 10
                        color: pageArrow.down ? "#154461"
                              : pageArrow.hovered ? "#123b54" : "#0e2b3d"
                        border.width: 1
                        border.color: pageArrow.hovered ? "#2c82ad" : "#1b536f"
                    }

                    contentItem: Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.pageIndex < root.pageCount - 1 ? "→" : "←"
                            color: "#e7f3f8"
                            font.pixelSize: 24
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.pageIndex + 1) + "/" + root.pageCount
                            color: "#86aabd"
                            font.pixelSize: 9
                        }
                    }

                    onClicked: {
                        root.pageIndex = root.pageIndex < root.pageCount - 1
                                ? root.pageIndex + 1 : 0
                    }
                }
            }

            // Reserve precisely the height missing between the two Local Images
            // cards and the responsive six-card Official/Developer grid.
            Item {
                width: parent.width
                height: visible
                        ? Math.max(0, root.platformGridHeight -
                                      pagedCards.height - content.spacing)
                        : 0
                visible: root.rootLevel && root.activeTab === 2
            }

            Flow {
                id: utilityFlow
                width: parent.width
                spacing: 10
                visible: false

                Repeater {
                    model: 0

                    delegate: Item {
                        id: utilityContainer
                        property var entry: index === 0 ? root.utilityAt(1) : root.utilityAt(2)
                        width: root.cardWidth
                        height: root.cardHeight

                        Button {
                            id: utilityButton
                            anchors.fill: parent
                            padding: 0
                            hoverEnabled: true

                            background: Rectangle {
                                radius: 10
                                color: utilityButton.down ? "#15374b"
                                      : utilityButton.hovered ? "#102f42" : "#0e2635"
                                border.width: 1
                                border.color: utilityButton.hovered ? "#2c7498" : "#1b4b64"
                            }

                            contentItem: Item {
                                Image {
                                    anchors.top: parent.top
                                    anchors.topMargin: 18
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 52
                                    height: 52
                                    source: index === 0
                                            ? "../icons/ui/custom-image-folder-file.svg"
                                            : "../icons/ui/erase-format-trash.svg"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                Column {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: 18
                                    width: parent.width - 20
                                    spacing: 3
                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: index === 0 ? qsTr("Use custom image") : qsTr("Erase / Format")
                                        color: "#f5f8fa"
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: utilityContainer.entry ? utilityContainer.entry.description : ""
                                        color: "#8eabba"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 10
                                    height: 30
                                    radius: 15
                                    color: utilityButton.hovered ? "#13527a" : "#103b55"
                                    border.width: 1
                                    border.color: "#175575"
                                    Text { anchors.centerIn: parent; text: "→"; color: "#d9e8ef"; font.pixelSize: 19 }
                                }
                            }

                            onClicked: {
                                if (utilityContainer.entry)
                                    root.itemSelected(utilityContainer.entry)
                            }
                        }
                    }
                }
            }
        }
    }
}
