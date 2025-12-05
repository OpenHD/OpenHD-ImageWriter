/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2024 OpenHD
 */

import QtQuick 2.9
import QtQuick.Window 2.2
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2
import Qt.labs.settings 1.0
import QtQuick.Dialogs 1.3
import "qmlcomponents"

Rectangle {
    id: window
    anchors.fill: parent
    color: "#34495E"

    FontLoader { id: roboto;      source: "fonts/Roboto-Regular.ttf" }
    FontLoader { id: robotoLight; source: "fonts/Roboto-Light.ttf" }
    FontLoader { id: robotoBold;  source: "fonts/Roboto-Bold.ttf" }

    property var mainWindow: null

    property bool driveSelected: false
    property string selectedDevice: ""
    property string selectedMountpoint: ""
    property string openhdRoot: ""

    // Settings map and values reused from OptionsPopup
    property var settingsMap: ({})
    property bool settingsMapLoaded: false
    property string bootType: ""
    property string sbc: ""
    property string camera: ""
    property string mode: ""
    property string hotSpot: ""
    property string beep: ""
    property string eject: ""
    property bool useSettings: true
    property string qopenhdConfPath: imageWriter.getValue("qopenhdConfPath")
    property bool qopenhdConfPresent: false

    Component.onCompleted: loadSettingsMap()

    function navigateBack() {
        if (mainWindow && mainWindow.showHome) {
            mainWindow.showHome()
        }
    }

    ToolButton {
        id: backButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        width: 28
        height: 28
        padding: 4
        hoverEnabled: true
        background: Rectangle { color: "transparent" }
        contentItem: Text {
            text: "\u2190"
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }
        onClicked: navigateBack()
    }

    Shortcut {
        sequence: StandardKey.Quit
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    ColumnLayout {
        id: bg
        spacing: 0
        anchors.fill: parent

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: driveSelected ? 0 : window.height / 2
            visible: !driveSelected
            color: "transparent"
ImButton {
                padding: 5
                id: donatebutton
                onClicked: {
                    Qt.openUrlExternally("https://opencollective.com/openhd");
                }
                visible: imageWriter.getValue("developer") !== "Kugelrund"
                Accessible.description: qsTr("Donate")
                contentItem: Image {
                    source: "icons/donate.svg"
                    fillMode: Image.PreserveAspectFit
                }
            }
            ImButton {
                padding: 5
                id: developerButton
                onClicked: {
                    Qt.openUrlExternally("https://openhdfpv.org");
                }
                visible: imageWriter.getValue("developer") == "Kugelrund"
                Accessible.description: qsTr("DEV")
                contentItem: Image {
                    source: "icons/dev.svg"
                    fillMode: Image.PreserveAspectFit
                }
            }
            Image {
                id: logo
                anchors.centerIn: parent
                source: "icons/logo_stacked_imager.png"
                fillMode: Image.PreserveAspectFit
                width: parent.width * 0.7
                height: parent.height
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: driveSelected ? window.height : window.height / 2
            color: "#2C3E50"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: driveSelected ? 16 : 32
                spacing: 12

                RowLayout {
                    spacing: 16
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        Text {
                            id: storageHeader
                            text: qsTr("Storage")
                            color: "#fff"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 17
                            Layout.preferredWidth: 100
                            font.pixelSize: 12
                            font.family: robotoBold.name
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        ImButton {
                            id: dstbutton
                            text: driveSelected ? selectedDevice : qsTr("CHOOSE STORAGE")
                            Layout.minimumHeight: 40
                            Layout.preferredWidth: 100
                            Layout.fillWidth: true
                            onClicked: {
                                imageWriter.startDriveListPolling()
                                dstpopup.open()
                                dstlist.forceActiveFocus()
                            }
                        }
                    }
                }

                ScrollView {
                    id: settingsScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 12
                    padding: 16
                    clip: true
                    visible: driveSelected
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 8
                            radius: width / 2
                            color: "#95A5A6"
                        }
                        background: Rectangle {
                            implicitWidth: 8
                            radius: width / 2
                            color: "#D6DDE3"
                        }
                    }
                    background: Rectangle {
                        radius: 10
                        color: "#ECF0F1"
                        border.color: "#C7D0D9"
                        border.width: 1
                    }
                    ColumnLayout {
                        id: settingsBody
                        width: settingsScroll.width - settingsScroll.leftPadding - settingsScroll.rightPadding
                        spacing: 16

                        GroupBox {
                            title: qsTr("Boot Mode")
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 0
                                Repeater {
                                    model: settingsMap.bootType && settingsMap.bootType.options ? settingsMap.bootType.options.filter(function(option) { return option.id && option.id.length > 0 }) : []
                                    delegate: ImCheckBox {
                                        property var option: modelData
                                        text: option ? option.id : ""
                                        checked: bootType === (option ? option.id : "")
                                        onClicked: {
                                            if (option) {
                                                bootType = option.id
                                                rebuildCameraSelectors()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        GroupBox {
                            title: qsTr("Camera")
                            Layout.fillWidth: true
                            Layout.minimumHeight: 80

                            ColumnLayout {
                                id: cameraLayout
                                spacing: 8

                                property var vendorList: []
                                property var selectedVendor: null

                                ListModel { id: vendorModel }
                                ListModel { id: cameraOptionsModel }

                                ComboBox {
                                    id: vendorSelector
                                    visible: vendorModel.count > 1
                                    textRole: "displayName"
                                    model: vendorModel
                                    Layout.minimumWidth: 220
                                    Layout.maximumHeight: 40
                                    onCurrentIndexChanged: {
                                        if (vendorModel.count > 0) {
                                            var modelVendor = vendorModel.get(currentIndex)
                                            if (modelVendor && modelVendor.vendorIndex >= 0 && modelVendor.vendorIndex < cameraLayout.vendorList.length) {
                                                cameraLayout.selectedVendor = cameraLayout.vendorList[modelVendor.vendorIndex]
                                                rebuildCameraOptions()
                                            }
                                        }
                                    }
                                }

                                ComboBox {
                                    id: cameraSelector
                                    textRole: "displayText"
                                    model: cameraOptionsModel
                                    Layout.minimumWidth: 220
                                    Layout.maximumHeight: 40
                                    onCurrentIndexChanged: {
                                        if (cameraOptionsModel.count > 0) {
                                            var selectedCamera = cameraOptionsModel.get(currentIndex).displayText
                                            if (selectedCamera !== "NONE") {
                                                camera = selectedCamera
                                            } else {
                                                camera = ""
                                            }
                                        }
                                    }
                                }

                                function rebuildCameraOptions() {
                                    cameraOptionsModel.clear()
                                    cameraOptionsModel.append({ displayText: "NONE", value: "" })

                                    if (cameraLayout.selectedVendor && cameraLayout.selectedVendor.options) {
                                        for (var i = 0; i < cameraLayout.selectedVendor.options.length; i++) {
                                            var option = cameraLayout.selectedVendor.options[i]
                                            cameraOptionsModel.append({ displayText: option.id, value: option.valueWritten })
                                        }
                                    }

                                    console.log("[Configure] camera options rebuilt for vendor", cameraLayout.selectedVendor ? cameraLayout.selectedVendor.id : "none", "->", cameraOptionsModel.count, "entries")

                                    var targetIndex = 0
                                    for (var idx = 0; idx < cameraOptionsModel.count; idx++) {
                                        if (cameraOptionsModel.get(idx).displayText === camera) {
                                            targetIndex = idx
                                        }
                                    }

                                    cameraSelector.currentIndex = targetIndex
                                }

                                function rebuildVendors() {
                                    vendorModel.clear()
                                    cameraLayout.vendorList = []

                                    var group = getCameraGroupForSelection()
                                    if (group && group.vendors) {
                                        cameraLayout.vendorList = group.vendors
                                    }

                                    for (var i = 0; i < cameraLayout.vendorList.length; i++) {
                                        var vendor = cameraLayout.vendorList[i]
                                        vendorModel.append({ displayName: vendor.displayName, vendorIndex: i })
                                    }
                                    console.log("[Configure] vendor list rebuilt for boot", bootType, "sbc", sbc, "->", vendorModel.count, "vendors")

                                    if (vendorModel.count > 0) {
                                        var index = vendorSelector.currentIndex >= 0 ? vendorSelector.currentIndex : 0
                                        var foundVendor = false
                                        for (var vendorIdx = 0; vendorIdx < cameraLayout.vendorList.length; vendorIdx++) {
                                            var vendorCandidate = cameraLayout.vendorList[vendorIdx]
                                            if (vendorCandidate && vendorCandidate.options) {
                                                for (var optIdx = 0; optIdx < vendorCandidate.options.length; optIdx++) {
                                                    if (vendorCandidate.options[optIdx].id === camera) {
                                                        index = vendorIdx
                                                        foundVendor = true
                                                        break
                                                    }
                                                }
                                                if (foundVendor) {
                                                    break
                                                }
                                            }
                                        }

                                        vendorSelector.currentIndex = index
                                        cameraLayout.selectedVendor = cameraLayout.vendorList[index]
                                    } else {
                                        cameraLayout.selectedVendor = null
                                    }
                                    rebuildCameraOptions()
                                }
                            }
                        }

                        GroupBox {
                            title: qsTr("Misc Settings")
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 8

                                ImCheckBox {
                                    id: setDebug
                                    visible: settingsMap.mode && settingsMap.mode.options && settingsMap.mode.options.length > 0
                                    text: settingsMap.mode && settingsMap.mode.options && settingsMap.mode.options.length > 0 ? qsTr(settingsMap.mode.options[0].id || "Debug Mode") : qsTr("Debug Mode")
                                    onCheckedChanged: {
                                        if (checked) {
                                            mode = "debug"
                                        } else {
                                            mode = ""
                                        }
                                    }
                                }

                                ImCheckBox {
                                    id: setWifiHotspot
                                    visible: settingsMap.hotSpot && settingsMap.hotSpot.options && settingsMap.hotSpot.options.length > 0
                                    text: settingsMap.hotSpot && settingsMap.hotSpot.options && settingsMap.hotSpot.options.length > 0 ? qsTr(settingsMap.hotSpot.options[0].id || "WifiHotspot") : qsTr("WifiHotspot")
                                    onCheckedChanged: {
                                        if (checked) {
                                            hotSpot = "wifi"
                                        } else {
                                            hotSpot = ""
                                        }
                                    }
                                }
                            }
                        }

                        GroupBox {
                            title: qsTr("QOpenHD.conf")
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 8

                                TextField {
                                    id: qopenhdConfDisplay
                                    Layout.fillWidth: true
                                    readOnly: true
                                    placeholderText: qsTr("No QOpenHD.conf selected")
                                    text: qopenhdConfPath
                                }

                                RowLayout {
                                    spacing: 8

                                    Button {
                                        text: qsTr("Choose File")
                                        onClicked: qopenhdConfDialog.open()
                                    }

                                    Button {
                                        text: qsTr("Clear Selection")
                                        enabled: qopenhdConfPath.length > 0
                                        onClicked: qopenhdConfPath = ""
                                    }
                                }

                                Label {
                                    visible: qopenhdConfPresent
                                    text: qsTr("A QOpenHD.conf is already present on the drive.")
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }

                                Label {
                                    visible: qopenhdConfPath.length === 0
                                    text: qsTr("Keep the existing file or select a new one to replace it.")
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 12
                    visible: driveSelected

                    //ImButton {
                    //    id: readButton
                    //    text: qsTr("READ SETTINGS")
                    //    Layout.minimumHeight: 40
                    //    onClicked: reloadSettingsFromDrive()
                    //}

                    ImButton {
                        id: writeButton
                        text: qsTr("WRITE SETTINGS")
                        Layout.minimumHeight: 40
                        onClicked: writeSettingsToDrive()
                    }
                }
            }
        }
    }

    Popup {
        id: dstpopup
        x: 50
        y: 25
        width: parent.width - 100
        height: parent.height - 50
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: imageWriter.stopDriveListPolling()

        Rectangle {
            color: "#f5f5f5"
            anchors.right: parent.right
            anchors.top: parent.top
            height: 35
            width: parent.width
        }
        Rectangle {
            color: "#afafaf"
            width: parent.width
            y: 35
            implicitHeight: 1
        }

        Text {
            text: "X"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 25
            anchors.topMargin: 10
            font.family: roboto.name
            font.bold: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: dstpopup.close()
            }
        }

        ColumnLayout {
            spacing: 10

            Text {
                text: qsTr("Storage")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
                Layout.topMargin: 10
                font.family: roboto.name
                font.bold: true
            }

            Item {
                clip: true
                Layout.preferredWidth: dstlist.width
                Layout.preferredHeight: dstlist.height

                ListView {
                    id: dstlist
                    model: driveListModel
                    delegate: dstdelegate
                    width: window.width - 100
                    height: window.height - 100
                    boundsBehavior: Flickable.StopAtBounds
                    highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
                    ScrollBar.vertical: ScrollBar {
                        width: 10
                        policy: dstlist.contentHeight > dstlist.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    }
                    Keys.onSpacePressed: {
                        if (currentIndex == -1)
                            return
                        selectDstItem(currentItem)
                    }
                    Accessible.onPressAction: {
                        if (currentIndex == -1)
                            return
                        selectDstItem(currentItem)
                    }
                    Keys.onEnterPressed: Keys.onSpacePressed(event)
                    Keys.onReturnPressed: Keys.onSpacePressed(event)
                }

            }
        }
    }

    Component {
        id: dstdelegate
        Item {
            width: window.width - 100
            height: 60
            Accessible.name: {
                var txt = description + " - " + (size/1000000000).toFixed(1) + " gigabytes"
                if (mountpoints.length > 0) {
                    txt += qsTr("Mounted as %1").arg(mountpoints.join(", "))
                }
                return txt;
            }
            property string description: model.description
            property string device: model.device
            property string size: model.size
            property bool isUsb: model.isUsb
            property bool isScsi: model.isScsi
            property bool isReadOnly: model.isReadOnly
            property var mountpoints: model.mountpoints

            Rectangle {
                id: dstbgrect
                anchors.fill: parent
                color: "#f5f5f5"
                visible: mouseOver && parent.ListView.view.currentIndex !== index
                property bool mouseOver: false

            }

            Rectangle {
                id: dstborderrect
                implicitHeight: 1
                implicitWidth: parent.width
                color: "#dcdcdc"
                y: parent.height
            }

            Row {
                leftPadding: 25

                Column {
                    width: 64

                    Image {
                        source: isUsb ? "icons/ic_usb_40px.svg" : isScsi ? "icons/ic_storage_40px.svg" : "icons/ic_sd_storage_40px.svg"
                        verticalAlignment: Image.AlignVCenter
                        height: parent.parent.parent.height
                        fillMode: Image.Pad
                    }
                }

                Column {
                    width: parent.parent.width - 64

                    Text {
                        textFormat: Text.StyledText
                        height: parent.parent.parent.height
                        verticalAlignment: Text.AlignVCenter
                        font.family: roboto.name
                        text: {
                            var sizeStr = (size/1000000000).toFixed(1) + " GB";
                            var txt;
                            if (isReadOnly) {
                                txt = "<p><font size='4' color='grey'>" + description + " - " + sizeStr + "</font></p>";
                                txt += "<font color='grey'>";
                                if (mountpoints.length > 0) {
                                    txt += qsTr("Mounted as %1").arg(mountpoints.join(", ")) + " "
                                }
                                txt += qsTr("[WRITE PROTECTED]") + "</font>";
                            } else {
                                txt = "<p><font size='4'>" + description + " - " + sizeStr + "</font></p>";
                                if (mountpoints.length > 0) {
                                    txt += "<font color='grey'>" + qsTr("Mounted as %1").arg(mountpoints.join(", ")) + "</font>";
                                }
                            }
                            return txt;
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onEntered: {
                    dstbgrect.mouseOver = true
                }

                onExited: {
                    dstbgrect.mouseOver = false
                }

                onClicked: {
                    selectDstItem(model)
                }
            }
        }
    }

    MsgPopup {
        id: msgpopup
    }

    FileDialog {
        id: qopenhdConfDialog
        title: qsTr("Select QOpenHD.conf")
        nameFilters: [qsTr("QOpenHD.conf (*.conf)"), qsTr("All files (*)")]
        selectExisting: true
        onAccepted: {
            qopenhdConfPath = qopenhdConfDialog.fileUrl.toLocalFile()
        }
    }

    function selectDstItem(d) {
        if (d.isReadOnly) {
            onError(qsTr("SD card is write protected.<br>Push the lock switch on the left side of the card upwards, and try again."))
            return
        }

        dstpopup.close()
        imageWriter.setDst(d.device, d.size)
        dstbutton.text = d.description

        selectedDevice = d.description
        selectedMountpoint = d.mountpoints && d.mountpoints.length > 0 ? normalizeMountpoint(d.mountpoints[0]) : ""
        openhdRoot = selectedMountpoint ? selectedMountpoint + "/openhd" : ""
        driveSelected = openhdRoot.length > 0

        console.log("[Configure] drive selected", selectedDevice, "at", selectedMountpoint)

        if (driveSelected) {
            loadSettingsMap()
            loadSettingsFromDrive()
            rebuildCameraSelectors()
        } else {
            console.log("[Configure] No mountpoint found for drive; cannot load settings")
        }
    }

    function onError(msg) {
        msgpopup.title = qsTr("Error")
        msgpopup.text = msg
        msgpopup.openPopup()
    }

    function normalizeMountpoint(mp) {
        if (!mp)
            return ""

        var normalized = mp
        if (normalized.endsWith("/"))
            normalized = normalized.slice(0, -1)
        if (normalized.endsWith("\\"))
            normalized = normalized.slice(0, -1)
        return normalized
    }

    function drivePath(relativePath) {
        if (!openhdRoot)
            return ""
        var rel = relativePath
        if (rel.startsWith("openhd/"))
            rel = rel.slice(7)
        if (rel.startsWith("/"))
            rel = rel.slice(1)
        return openhdRoot + "/" + rel
    }

    function qopenhdConfRelativePath() {
        if (settingsMap.qopenhdConf && settingsMap.qopenhdConf.file)
            return settingsMap.qopenhdConf.file
        return "openhd/QOpenHD.conf"
    }

    function loadSettingsMap() {
        if (settingsMapLoaded)
            return

        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl("qrc:/doc/openhd_settings_map.json"), false)
        xhr.send()

        try {
            settingsMap = JSON.parse(xhr.responseText)
            settingsMapLoaded = true
            console.log("[Configure] settings map loaded with keys:", Object.keys(settingsMap))
        } catch (e) {
            console.log("[Configure] Failed to load OpenHD settings map: " + e)
        }
    }

    function getCameraGroupForSelection() {
        if (!settingsMap.camera || !settingsMap.camera.sbcGroups)
            return null

        for (var i = 0; i < settingsMap.camera.sbcGroups.length; i++) {
            var group = settingsMap.camera.sbcGroups[i]
            if (!group || !group.sbc || !group.bootTypeRequired)
                continue
            if (group.sbc.indexOf(sbc) !== -1 && group.bootTypeRequired === bootType) {
                return group
            }
        }
        return null
    }

    function rebuildCameraSelectors() {
        cameraLayout.rebuildVendors()
    }

    function cameraValueForSelection() {
        var group = getCameraGroupForSelection()
        if (!group || !group.vendors)
            return ""

        for (var i = 0; i < group.vendors.length; i++) {
            var vendor = group.vendors[i]
            if (!vendor || !vendor.options)
                continue

            for (var optIdx = 0; optIdx < vendor.options.length; optIdx++) {
                var opt = vendor.options[optIdx]
                if (opt && opt.id === camera) {
                    return opt.valueWritten || ""
                }
            }
        }
        return ""
    }

    function setCameraFromValue(encodedValue) {
        var group = getCameraGroupForSelection()
        if (!group || !group.vendors)
            return

        for (var i = 0; i < group.vendors.length; i++) {
            var vendor = group.vendors[i]
            if (!vendor || !vendor.options)
                continue

            for (var optIdx = 0; optIdx < vendor.options.length; optIdx++) {
                var opt = vendor.options[optIdx]
                if (opt && opt.valueWritten === encodedValue) {
                    camera = opt.id
                    cameraLayout.selectedVendor = vendor
                    console.log("[Configure] Camera loaded from drive:", camera)
                    cameraLayout.rebuildCameraOptions()
                    return
                }
            }
        }
    }

    function loadSettingsFromDrive() {
        if (!openhdRoot) {
            console.log("[Configure] No mountpoint available to load settings")
            return
        }

        console.log("[Configure] Loading settings from", openhdRoot)

        // Reset any previous selection before reading from storage
        bootType = ""
        sbc = ""
        camera = ""
        mode = ""
        qopenhdConfPresent = false

        var airFile = drivePath("air.txt")
        var groundFile = drivePath("ground.txt")
        if (imageWriter.fileExists(airFile)) {
            bootType = "Air"
        } else if (imageWriter.fileExists(groundFile)) {
            bootType = "Ground"
        } else if (settingsMap.bootType && settingsMap.bootType.options && settingsMap.bootType.options.length > 0) {
            bootType = settingsMap.bootType.options[0].id
        }

        // Detect SBC marker
        if (settingsMap.sbc && settingsMap.sbc.options) {
            for (var i = 0; i < settingsMap.sbc.options.length; i++) {
                var opt = settingsMap.sbc.options[i]
                var optPath = drivePath(opt.file)
                if (imageWriter.fileExists(optPath)) {
                    sbc = opt.id
                    break
                }
            }
            if (!sbc && settingsMap.sbc.options.length > 0) {
                sbc = settingsMap.sbc.options[0].id
            }
        }

        if (imageWriter.fileExists(drivePath("debug.txt"))) {
            mode = "debug"
            setDebug.checked = true
        } else {
            mode = ""
            setDebug.checked = false
        }

        var cameraValue = imageWriter.readTextFile(drivePath("camera1.txt")).trim()
        if (cameraValue.length > 0) {
            setCameraFromValue(cameraValue)
        } else {
            camera = ""
        }

        qopenhdConfPresent = imageWriter.fileExists(drivePath(qopenhdConfRelativePath()))

        console.log("[Configure] Loaded settings -> bootType:", bootType, "sbc:", sbc, "camera:", camera)
    }

    function reloadSettingsFromDrive() {
        if (!driveSelected) {
            console.log("[Configure] Cannot reload settings; no drive selected")
            return
        }

        loadSettingsFromDrive()
        rebuildCameraSelectors()
    }

    function writeSettingsToDrive() {
        if (!driveSelected || !openhdRoot) {
            console.log("[Configure] No drive selected, skipping write")
            return
        }

        console.log("[Configure] Writing settings to", openhdRoot)

        var bootFile = bootType === "Air" ? "air.txt" : (bootType === "Ground" ? "ground.txt" : "")
        if (bootFile) {
            imageWriter.writeTextFile(drivePath(bootFile), "")
            var otherBoot = bootType === "Air" ? "ground.txt" : "air.txt"
            imageWriter.removeFile(drivePath(otherBoot))
        }

        if (settingsMap.sbc && settingsMap.sbc.options) {
            for (var i = 0; i < settingsMap.sbc.options.length; i++) {
                var opt = settingsMap.sbc.options[i]
                var targetPath = drivePath(opt.file)
                if (opt.id === sbc) {
                    imageWriter.writeTextFile(targetPath, "")
                } else {
                    imageWriter.removeFile(targetPath)
                }
            }
        }

        if (mode === "debug") {
            imageWriter.writeTextFile(drivePath("debug.txt"), "")
        } else {
            imageWriter.removeFile(drivePath("debug.txt"))
        }

        var camValue = cameraValueForSelection()
        if (camValue && camValue.length > 0) {
            imageWriter.writeTextFile(drivePath("camera1.txt"), camValue)
        } else {
            imageWriter.removeFile(drivePath("camera1.txt"))
        }

        if (qopenhdConfPath && qopenhdConfPath.length > 0) {
            var qopenhdTarget = drivePath(qopenhdConfRelativePath())
            if (!imageWriter.copyFile(qopenhdConfPath, qopenhdTarget)) {
                onError(qsTr("Failed to copy QOpenHD.conf to the drive."))
                return
            }
            qopenhdConfPresent = true
        } else {
            qopenhdConfPresent = imageWriter.fileExists(drivePath(qopenhdConfRelativePath()))
        }

        imageWriter.setSetting("bootType", bootType)
        imageWriter.setSetting("sbc", sbc)
        imageWriter.setSetting("camera", camera)
        imageWriter.setSetting("mode", mode)
        imageWriter.setSetting("qopenhdConfPath", qopenhdConfPath)

        console.log("[Configure] Settings written: bootType", bootType, "sbc", sbc, "camera", camera)
    }
}
