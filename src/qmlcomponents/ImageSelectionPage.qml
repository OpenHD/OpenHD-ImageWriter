import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    // ─── Public API ───────────────────────────────────────────────────────────
    property var  sourceModel: null
    property bool rootLevel: true
    property string categoryName: ""
    property string pageTitle:      qsTr("Choose an image")
    property string pageSubtitle:   qsTr("Select the device or image you want to write.")
    property string nestedSubtitle: qsTr("Choose the OpenHD release to use for this device.")
    property string userDefinedTitle: qsTr("Use custom image")
    property string formatTitle:      qsTr("Erase / Format")

    // Tab index (Official=0, Developer=1, Local=2) — only at root level
    property int activeTab: 0

    readonly property bool narrow: width < 520
    readonly property int  sourceCount:    sourceModel ? sourceModel.count : 0
    readonly property int  itemOffset:     rootLevel ? 0 : 1
    readonly property int  mainItemCount:  Math.max(0, sourceCount - (rootLevel ? 2 : 1))

    signal itemSelected(var item)
    signal closeRequested()

    focus: visible
    onVisibleChanged: { if (visible) forceActiveFocus() }

    function itemAt(displayIndex) {
        return sourceModel ? sourceModel.get(displayIndex + itemOffset) : null
    }
    function utilityAt(offsetFromEnd) {
        return sourceModel ? sourceModel.get(sourceCount - offsetFromEnd) : null
    }
    function goBack() {
        if (rootLevel)      closeRequested()
        else if (sourceModel && sourceModel.count > 0)
            itemSelected(sourceModel.get(0))
    }

    // ─── Platform icon resolver ───────────────────────────────────────────────
    // Maps keywords found in entry names/descriptions to bundled platform icons.
    // YAML icon fields are intentionally ignored here; the application controls presentation.
    function platformIcon(name, desc) {
        var s = (name + " " + (desc || "")).toLowerCase()
        if (s.indexOf("raspberry") >= 0)        return "../icons/platforms/raspberrypi.svg"
        if (s.indexOf("radxa") >= 0)            return "../icons/platforms/radxa.svg"
        if (s.indexOf("x86") >= 0
         || s.indexOf("evo") >= 0
         || s.indexOf("desktop") >= 0
         || s.indexOf("intel") >= 0
         || s.indexOf("amd") >= 0
         || s.indexOf("laptop") >= 0
         || s.indexOf("computer") >= 0)         return "../icons/platforms/x86.svg"
        if (s.indexOf("openhd") >= 0
         || s.indexOf("custom hardware") >= 0)  return "../icons/platforms/openhd.svg"
        return "../icons/platforms/generic-sbc.svg"
    }

    Keys.onEscapePressed: goBack()

    // ─── Background ───────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#0d1b26" }

    // ─── Back breadcrumb (sub-category only) ──────────────────────────────────
    Item {
        id: breadcrumb
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: !root.rootLevel ? 36 : 0
        visible: !root.rootLevel

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 14
            spacing: 4

            Text {
                text: "‹"
                color: "#4a9eff"
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: qsTr("Back")
                color: "#4a9eff"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goBack()
                }
            }
        }
    }

    // ─── Page header ──────────────────────────────────────────────────────────
    Item {
        id: pageHeader
        anchors.top: breadcrumb.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: headerCol.implicitHeight + 20

        Column {
            id: headerCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                text: root.rootLevel || root.categoryName.length === 0
                      ? root.pageTitle
                      : root.categoryName
                color: "#ddeaf5"
                font.pixelSize: 20
                font.bold: true
            }

            Text {
                text: root.rootLevel ? root.pageSubtitle : root.nestedSubtitle
                color: "#6b8da4"
                font.pixelSize: 13
            }
        }
    }

    // ─── Segmented tab control ────────────────────────────────────────────────
    Item {
        id: tabBar
        anchors.top: pageHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: root.rootLevel ? 36 : 0
        visible: root.rootLevel

        // Outer container — the segmented pill
        Rectangle {
            id: tabPill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 34
            radius: 6
            color: "#0b1720"
            border.color: "#1e3347"
            border.width: 1
            width: tabRow.implicitWidth + 2

            Row {
                id: tabRow
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: [
                        qsTr("Official Releases"),
                        qsTr("Developer Versions"),
                        qsTr("Local Images")
                    ]

                    delegate: Item {
                        width: tabText.implicitWidth + 20
                        height: 34

                        // Active tab fill
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 5
                            color: "#1a6ab0"
                            visible: root.activeTab === index
                        }

                        // Divider between inactive tabs
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            width: 1
                            color: "#1e3347"
                            visible: index < 2 && root.activeTab !== index && root.activeTab !== (index + 1)
                        }

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData
                            color: root.activeTab === index ? "#ffffff" : "#6b8da4"
                            font.pixelSize: 13
                            font.bold: root.activeTab === index
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = index
                        }
                    }
                }
            }
        }
    }

    // ─── Spacer between tab and list ─────────────────────────────────────────
    Item {
        id: spacer
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 8
    }

    // ─── Grouped list panel ───────────────────────────────────────────────────
    Rectangle {
        id: listPanel
        anchors.top: spacer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 12
        radius: 6
        color: "#0f2030"
        border.color: "#1e3347"
        border.width: 1
        clip: true

        Flickable {
            id: listScroll
            anchors.fill: parent
            contentWidth: width
            contentHeight: listContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: listContent
                width: listScroll.width

                // Loading indicator
                Item {
                    width: listScroll.width
                    height: 60
                    visible: root.mainItemCount === 0

                    Row {
                        anchors.centerIn: parent
                        spacing: 10

                        BusyIndicator {
                            width: 20; height: 20
                            running: parent.parent.visible
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Loading available images...")
                            color: "#6b8da4"
                            font.pixelSize: 13
                        }
                    }
                }

                // Main platform rows (from remote JSON)
                Repeater {
                    id: mainRepeater
                    model: root.mainItemCount

                    delegate: Item {
                        property var entry: root.itemAt(index)
                        // Visibility based on active tab
                        // Tab 0 = Official: show items that don't look like dev/local
                        // Tab 1 = Developer: items whose name/desc mentions beta/dev/nightly
                        // Tab 2 = Local: not shown here (handled by utility rows below)
                        readonly property bool matchesOfficialTab: {
                            if (!entry) return false
                            var n = (entry.name + " " + (entry.description || "")).toLowerCase()
                            return n.indexOf("beta") < 0 && n.indexOf("nightly") < 0
                                && n.indexOf("dev") < 0 && n.indexOf("snapshot") < 0
                        }
                        readonly property bool matchesDeveloperTab: {
                            if (!entry) return false
                            var n = (entry.name + " " + (entry.description || "")).toLowerCase()
                            return n.indexOf("beta") >= 0 || n.indexOf("nightly") >= 0
                                || n.indexOf("dev") >= 0 || n.indexOf("snapshot") >= 0
                        }

                        visible: !root.rootLevel ||
                                 (root.activeTab === 0 && (matchesOfficialTab || !matchesDeveloperTab)) ||
                                 (root.activeTab === 1 && matchesDeveloperTab) ||
                                 root.activeTab === 2
                        height: visible ? selRow.implicitHeight : 0

                        SelectionRow {
                            id: selRow
                            width: parent.width
                            visible: parent.visible
                            title: entry ? entry.name : ""
                            description: entry ? entry.description : ""
                            iconSource: root.platformIcon(
                                            entry ? entry.name : "",
                                            entry ? entry.description : "")
                            showSeparator: index < root.mainItemCount - 1 || root.sourceCount >= 2
                            onClicked: {
                                if (entry) root.itemSelected(entry)
                            }
                        }
                    }
                }

                // ─── Utility section: "Use custom" + "Erase/Format" ───────────
                // These appear in the "Local Images" tab at root level
                Item {
                    width: listScroll.width
                    height: (root.rootLevel && root.sourceCount >= 2 &&
                             (root.activeTab === 2 || !root.rootLevel)) ? divLine.height : 0
                    visible: height > 0

                    Rectangle {
                        id: divLine
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 60
                        height: 1
                        color: "#1e3347"
                    }
                }

                Repeater {
                    model: (root.rootLevel && root.sourceCount >= 2 &&
                            (root.activeTab === 2 || !root.rootLevel)) ? 2 : 0

                    delegate: Item {
                        property var entry: index === 0 ? root.utilityAt(1) : root.utilityAt(2)
                        property string utTitle: index === 0 ? root.userDefinedTitle : root.formatTitle
                        width: listScroll.width
                        height: utRow.implicitHeight

                        SelectionRow {
                            id: utRow
                            width: parent.width
                            title: entry ? utTitle : ""
                            description: entry ? entry.description : ""
                            iconSource: index === 0 ? "../icons/use_custom.png" : "../icons/erase.png"
                            showSeparator: index === 0
                            onClicked: {
                                if (entry) root.itemSelected(entry)
                            }
                        }
                    }
                }

                // Bottom padding inside panel
                Item { width: 1; height: 4 }
            }
        }
    }
}
