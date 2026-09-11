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
    color: "#0c202c"

    FontLoader { id: roboto;      source: "fonts/Roboto-Regular.ttf" }
    FontLoader { id: robotoLight; source: "fonts/Roboto-Light.ttf" }
    FontLoader { id: robotoBold;  source: "fonts/Roboto-Bold.ttf" }

    property var mainWindow: null

    property bool driveSelected: false
    property bool selectingTarget: false
    property string selectedDevice: ""
    property string selectedMountpoint: ""
    property string openhdRoot: ""

    // Settings map and values shared with the image configuration page.
    property var settingsMap: ({})
    property bool settingsMapLoaded: false
    property string bootType: ""
    property string sbc: ""
    property string camera: ""
    property string camera2: ""
    property string cameraResolution: ""
    property string camera2Resolution: ""
    property string cameraPort: "cam1"
    property string camera2Port: "cam0"
    property string ipCameraAddress: "192.168.144.108"
    property string ipCameraPipeline: "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
    property string camera2IpCameraAddress: "192.168.144.108"
    property string camera2IpCameraPipeline: "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
    property int ipCameraBitrate: 2
    property bool displayForceMode: false
    property int displayWidth: 1920
    property int displayHeight: 1080
    property int displayRefreshHz: 60
    property string mode: ""
    property string hotSpot: ""
    property string beep: ""
    property string eject: ""
    property bool useSettings: true
    property string qopenhdConfPath: ""
    property bool qopenhdConfPresent: false
    property string premiumCertificatePath: ""
    property bool premiumCertificatePresent: false
    property bool returnHomeAfterPopupClose: false
    property string language: ""
    property string token: ""

    Component.onCompleted: {
        qopenhdConfPath = normalizeLocalFilePath(imageWriter.getValue("qopenhdConfPath"))
        premiumCertificatePath = normalizeLocalFilePath(imageWriter.getValue("premiumCertificatePath"))
        language = imageWriter.getValue("language")
        token = imageWriter.getValue("token")
        loadSettingsMap()
    }

    function navigateBack() {
        if (selectingTarget) {
            selectingTarget = false
            imageWriter.stopDriveListPolling()
            return
        }

        if (mainWindow && mainWindow.showHome) {
            mainWindow.showHome()
        }
    }

    ToolButton {
        id: backButton
        visible: false
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        z: 10
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
        visible: !selectingTarget
        enabled: visible

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 0
            visible: false
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
                width: Math.min(parent.width * 0.62, 480)
                height: parent.height - 16
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: driveSelected ? window.height : window.height * 0.7
            color: "#0c202c"

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: window.width < 700 ? 24 : 38
                anchors.bottomMargin: 20
                anchors.leftMargin: window.width < 700 ? 20 : 40
                anchors.rightMargin: window.width < 700 ? 20 : 40
                spacing: 18

                PageHeader {
                    Layout.fillWidth: true
                    title: qsTr("Configure OpenHD media")
                    subtitle: driveSelected
                              ? qsTr("Adjust the settings that will be written to the selected OpenHD storage.")
                              : qsTr("Select an OpenHD storage device to inspect and configure its settings.")
                }

                RowLayout {
                    spacing: 16
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        ActionCard {
                            id: dstbutton
                            text: driveSelected ? selectedDevice : qsTr("No storage selected")
                            eyebrow: qsTr("Configuration target")
                            description: driveSelected
                                         ? qsTr("Settings will be saved to this OpenHD storage device.")
                                         : qsTr("Choose the SD card or USB storage containing OpenHD.")
                            actionText: driveSelected ? qsTr("Change target") : qsTr("Choose storage")
                            iconSource: "icons/ui/drive.svg"
                            Layout.preferredHeight: 142
                            Layout.fillWidth: true
                            onClicked: {
                                imageWriter.startDriveListPolling()
                                selectingTarget = true
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
                        color: "#0e2734"
                        border.color: "#294754"
                        border.width: 1
                    }
                    ColumnLayout {
                        id: settingsBody
                        width: settingsScroll.width - settingsScroll.leftPadding - settingsScroll.rightPadding
                        spacing: 16

                        SettingsSection {
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
                                                if (bootType !== "Air") {
                                                    camera = ""
                                                    camera2 = ""
                                                    cameraResolution = ""
                                                    camera2Resolution = ""
                                                }
                                                rebuildCameraSelectors()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SettingsSection {
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
                                ListModel { id: camera2OptionsModel }
                                ListModel { id: cameraResolutionOptionsModel }
                                ListModel { id: camera2ResolutionOptionsModel }

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

                                GridLayout {
                                    columns: 2
                                    columnSpacing: 12
                                    rowSpacing: 6
                                    Layout.fillWidth: true

                                    Label {
                                        text: qsTr("Primary camera")
                                    }

                                    Label {
                                        text: qsTr("Primary resolution")
                                        visible: camera.length > 0 && cameraResolutionOptionsModel.count > 0
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
                                                cameraLayout.rebuildPrimaryResolutionOptions()
                                            }
                                        }
                                    }

                                    ComboBox {
                                        id: cameraResolutionSelector
                                        textRole: "label"
                                        model: cameraResolutionOptionsModel
                                        Layout.minimumWidth: 220
                                        Layout.maximumHeight: 40
                                        visible: camera.length > 0 && cameraResolutionOptionsModel.count > 0
                                        onCurrentIndexChanged: {
                                            if (cameraResolutionOptionsModel.count > 0 && currentIndex >= 0) {
                                                var selectedResolution = cameraResolutionOptionsModel.get(currentIndex)
                                                cameraResolution = selectedResolution && selectedResolution.value ? selectedResolution.value : ""
                                            }
                                        }
                                    }

                                    Label {
                                        text: qsTr("Secondary camera")
                                        Layout.topMargin: 4
                                    }

                                    Label {
                                        text: qsTr("Secondary resolution")
                                        Layout.topMargin: 4
                                        visible: camera2.length > 0 && camera2ResolutionOptionsModel.count > 0
                                    }

                                    ComboBox {
                                        id: camera2Selector
                                        textRole: "label"
                                        model: camera2OptionsModel
                                        Layout.minimumWidth: 220
                                        Layout.maximumHeight: 40
                                        onCurrentIndexChanged: {
                                            if (camera2OptionsModel.count > 0) {
                                                var selectedSecondary = camera2OptionsModel.get(currentIndex)
                                                camera2 = selectedSecondary && selectedSecondary.cameraId ? selectedSecondary.cameraId : ""
                                                cameraLayout.rebuildSecondaryResolutionOptions()
                                            }
                                        }
                                    }

                                    ComboBox {
                                        id: camera2ResolutionSelector
                                        textRole: "label"
                                        model: camera2ResolutionOptionsModel
                                        Layout.minimumWidth: 220
                                        Layout.maximumHeight: 40
                                        visible: camera2.length > 0 && camera2ResolutionOptionsModel.count > 0
                                        onCurrentIndexChanged: {
                                            if (camera2ResolutionOptionsModel.count > 0 && currentIndex >= 0) {
                                                var selectedSecondaryResolution = camera2ResolutionOptionsModel.get(currentIndex)
                                                camera2Resolution = selectedSecondaryResolution && selectedSecondaryResolution.value ? selectedSecondaryResolution.value : ""
                                            }
                                        }
                                    }
                                }

                                function normalizeCameraValueForResolutionLookup(encodedValue) {
                                    if (encodedValue === "1")
                                        return "10"
                                    return encodedValue
                                }

                                function resolutionListForCameraValue(encodedValue) {
                                    if (!settingsMap.cameraResolution || !settingsMap.cameraResolution.byCameraValue || !encodedValue || encodedValue.length === 0)
                                        return []
                                    var normalizedValue = normalizeCameraValueForResolutionLookup(encodedValue)
                                    var resolutionList = settingsMap.cameraResolution.byCameraValue[normalizedValue]
                                    if (!resolutionList || !resolutionList.length)
                                        return []
                                    return resolutionList
                                }

                                function rebuildPrimaryResolutionOptions() {
                                    cameraResolutionOptionsModel.clear()

                                    var selectedCamera = (cameraOptionsModel.count > 0 && cameraSelector.currentIndex >= 0) ? cameraOptionsModel.get(cameraSelector.currentIndex) : null
                                    var encodedCameraValue = selectedCamera && selectedCamera.value ? selectedCamera.value : ""
                                    if (!selectedCamera || selectedCamera.displayText === "NONE")
                                        encodedCameraValue = ""

                                    var resolutions = resolutionListForCameraValue(encodedCameraValue)
                                    var seenResolutions = {}
                                    for (var i = 0; i < resolutions.length; i++) {
                                        var resolutionValue = resolutions[i]
                                        if (resolutionValue === "0x0@0")
                                            continue
                                        if (seenResolutions[resolutionValue])
                                            continue
                                        seenResolutions[resolutionValue] = true
                                        cameraResolutionOptionsModel.append({ label: resolutionValue, value: resolutionValue })
                                    }

                                    if (!camera || camera.length === 0 || !encodedCameraValue || encodedCameraValue.length === 0) {
                                        cameraResolution = ""
                                    }

                                    var targetIndex = 0
                                    if (cameraResolution && cameraResolution.length > 0) {
                                        for (var idx = 0; idx < cameraResolutionOptionsModel.count; idx++) {
                                            if (cameraResolutionOptionsModel.get(idx).value === cameraResolution) {
                                                targetIndex = idx
                                                break
                                            }
                                        }
                                    }
                                    cameraResolutionSelector.currentIndex = cameraResolutionOptionsModel.count > 0 ? targetIndex : -1

                                    if (cameraResolutionOptionsModel.count > 0) {
                                        var currentResolution = cameraResolutionOptionsModel.get(cameraResolutionSelector.currentIndex)
                                        cameraResolution = currentResolution && currentResolution.value ? currentResolution.value : ""
                                    } else {
                                        cameraResolution = ""
                                    }
                                }

                                function rebuildSecondaryResolutionOptions() {
                                    camera2ResolutionOptionsModel.clear()

                                    var encodedCamera2Value = window.cameraValueForSelection(camera2)

                                    var resolutions = resolutionListForCameraValue(encodedCamera2Value)
                                    var seenResolutions = {}
                                    for (var i = 0; i < resolutions.length; i++) {
                                        var resolutionValue = resolutions[i]
                                        if (resolutionValue === "0x0@0")
                                            continue
                                        if (seenResolutions[resolutionValue])
                                            continue
                                        seenResolutions[resolutionValue] = true
                                        camera2ResolutionOptionsModel.append({ label: resolutionValue, value: resolutionValue })
                                    }

                                    if (!camera2 || camera2.length === 0 || !encodedCamera2Value || encodedCamera2Value.length === 0) {
                                        camera2Resolution = ""
                                    }

                                    var targetIndex = 0
                                    if (camera2Resolution && camera2Resolution.length > 0) {
                                        for (var idx = 0; idx < camera2ResolutionOptionsModel.count; idx++) {
                                            if (camera2ResolutionOptionsModel.get(idx).value === camera2Resolution) {
                                                targetIndex = idx
                                                break
                                            }
                                        }
                                    }
                                    camera2ResolutionSelector.currentIndex = camera2ResolutionOptionsModel.count > 0 ? targetIndex : -1

                                    if (camera2ResolutionOptionsModel.count > 0) {
                                        var currentResolution = camera2ResolutionOptionsModel.get(camera2ResolutionSelector.currentIndex)
                                        camera2Resolution = currentResolution && currentResolution.value ? currentResolution.value : ""
                                    } else {
                                        camera2Resolution = ""
                                    }
                                }

                                function rebuildSecondaryCameraOptions() {
                                    camera2OptionsModel.clear()
                                    camera2OptionsModel.append({ label: "NONE", cameraId: "" })
                                    var secondaryOptions = settingsMap.camera && settingsMap.camera.secondaryOptions ? settingsMap.camera.secondaryOptions : []
                                    for (var i = 0; i < secondaryOptions.length; i++) {
                                        var secondaryOption = secondaryOptions[i]
                                        camera2OptionsModel.append({ label: secondaryOption.displayName || secondaryOption.id, cameraId: secondaryOption.id })
                                    }

                                    var group = getCameraGroupForSelection()
                                    if (group && group.secondaryCsi && group.vendors) {
                                        for (var vendorIdx = 0; vendorIdx < group.vendors.length; vendorIdx++) {
                                            var vendorOptions = group.vendors[vendorIdx].options || []
                                            for (var optIdx = 0; optIdx < vendorOptions.length; optIdx++) {
                                                var csiOption = vendorOptions[optIdx]
                                                var cameraType = parseInt(csiOption.valueWritten)
                                                if (cameraType >= 20 && cameraType <= 69)
                                                    camera2OptionsModel.append({ label: "CSI - " + csiOption.id, cameraId: csiOption.id })
                                            }
                                        }
                                    }

                                    if (camera2 === "FLIR VUE")
                                        camera2 = "FLIR_VUE"
                                    else if (camera2 === "FLIR BOSON")
                                        camera2 = "FLIR_BOSON"

                                    var targetIndex2 = 0
                                    for (var idx2 = 0; idx2 < camera2OptionsModel.count; idx2++) {
                                        if (camera2OptionsModel.get(idx2).cameraId === camera2) {
                                            targetIndex2 = idx2
                                            break
                                        }
                                    }

                                    camera2Selector.currentIndex = targetIndex2
                                    rebuildSecondaryResolutionOptions()
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
                                    rebuildSecondaryCameraOptions()
                                    rebuildPrimaryResolutionOptions()
                                }

                                function rebuildVendors() {
                                    vendorModel.clear()
                                    cameraLayout.vendorList = []

                                    var group = getCameraGroupForSelection()
                                    if (group && group.vendors) {
                                        cameraLayout.vendorList = group.vendors.concat(
                                            settingsMap.camera && settingsMap.camera.commonVendors ? settingsMap.camera.commonVendors : [])
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

                        SettingsSection {
                            title: qsTr("Raspberry Pi 5 Camera Connectors")
                            Layout.fillWidth: true
                            visible: bootType === "Air" && sbc === "rpi" &&
                                     (isRpiCsiCamera(camera) || isRpiCsiCamera(camera2))

                            GridLayout {
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 8
                                Layout.fillWidth: true

                                Label { text: qsTr("Primary camera connector"); visible: isRpiCsiCamera(camera) }
                                ComboBox {
                                    visible: isRpiCsiCamera(camera)
                                    model: ["CAM0", "CAM1"]
                                    currentIndex: cameraPort === "cam0" ? 0 : 1
                                    onActivated: {
                                        cameraPort = currentIndex === 0 ? "cam0" : "cam1"
                                        if (isRpiCsiCamera(camera2) && camera2Port === cameraPort)
                                            camera2Port = cameraPort === "cam0" ? "cam1" : "cam0"
                                    }
                                }

                                Label { text: qsTr("Secondary camera connector"); visible: isRpiCsiCamera(camera2) }
                                ComboBox {
                                    visible: isRpiCsiCamera(camera2)
                                    model: ["CAM0", "CAM1"]
                                    currentIndex: camera2Port === "cam0" ? 0 : 1
                                    onActivated: {
                                        camera2Port = currentIndex === 0 ? "cam0" : "cam1"
                                        if (isRpiCsiCamera(camera) && cameraPort === camera2Port)
                                            cameraPort = camera2Port === "cam0" ? "cam1" : "cam0"
                                    }
                                }
                            }
                        }

                        SettingsSection {
                            title: qsTr("Ground display")
                            Layout.fillWidth: true
                            visible: bootType === "Ground"

                            ColumnLayout {
                                spacing: 8
                                ImCheckBox {
                                    text: qsTr("Force HDMI resolution and refresh rate")
                                    checked: displayForceMode
                                    onClicked: displayForceMode = checked
                                }
                                GridLayout {
                                    columns: 2
                                    enabled: displayForceMode
                                    Label { text: qsTr("Width") }
                                    SpinBox { from: 320; to: 7680; value: displayWidth; onValueModified: displayWidth = value }
                                    Label { text: qsTr("Height") }
                                    SpinBox { from: 240; to: 4320; value: displayHeight; onValueModified: displayHeight = value }
                                    Label { text: qsTr("Refresh rate (Hz)") }
                                    SpinBox { from: 20; to: 240; value: displayRefreshHz; onValueModified: displayRefreshHz = value }
                                }
                            }
                        }

                        SettingsSection {
                            title: qsTr("IP Camera Setup")
                            Layout.fillWidth: true
                            visible: bootType === "Air" && (camera === "IP-CAMERA" || camera2 === "IP-CAMERA")

                            GridLayout {
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 8
                                Layout.fillWidth: true

                                Label { text: qsTr("Primary camera IP"); visible: camera === "IP-CAMERA" }
                                TextField {
                                    visible: camera === "IP-CAMERA"
                                    Layout.minimumWidth: 420
                                    maximumLength: 15
                                    text: ipCameraAddress
                                    onEditingFinished: ipCameraAddress = text.trim()
                                }
                                Label { text: qsTr("Primary source pipeline"); visible: camera === "IP-CAMERA" }
                                TextField {
                                    visible: camera === "IP-CAMERA"
                                    Layout.minimumWidth: 420
                                    maximumLength: 127
                                    text: ipCameraPipeline
                                    onEditingFinished: ipCameraPipeline = text.trim()
                                }
                                Label { text: qsTr("Secondary camera IP"); visible: camera2 === "IP-CAMERA" }
                                TextField {
                                    visible: camera2 === "IP-CAMERA"
                                    Layout.minimumWidth: 420
                                    maximumLength: 15
                                    text: camera2IpCameraAddress
                                    onEditingFinished: camera2IpCameraAddress = text.trim()
                                }
                                Label { text: qsTr("Secondary source pipeline"); visible: camera2 === "IP-CAMERA" }
                                TextField {
                                    visible: camera2 === "IP-CAMERA"
                                    Layout.minimumWidth: 420
                                    maximumLength: 127
                                    text: camera2IpCameraPipeline
                                    onEditingFinished: camera2IpCameraPipeline = text.trim()
                                }
                                Label { text: qsTr("Reserved link bitrate (Mbit/s)") }
                                SpinBox {
                                    from: 1
                                    to: 20
                                    value: ipCameraBitrate
                                    editable: true
                                    onValueChanged: ipCameraBitrate = value
                                }
                            }
                        }

                        SettingsSection {
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

                        SettingsSection {
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

                        SettingsSection {
                            title: qsTr("Premium Certificate")
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 8

                                TextField {
                                    id: premiumCertificateDisplay
                                    Layout.fillWidth: true
                                    readOnly: true
                                    placeholderText: qsTr("No premium certificate selected")
                                    text: premiumCertificatePath
                                }

                                RowLayout {
                                    spacing: 8

                                    Button {
                                        text: qsTr("Choose File")
                                        onClicked: premiumCertificateDialog.open()
                                    }

                                    Button {
                                        text: qsTr("Clear Selection")
                                        enabled: premiumCertificatePath.length > 0
                                        onClicked: premiumCertificatePath = ""
                                    }
                                }

                                Label {
                                    visible: premiumCertificatePresent
                                    text: qsTr("A premium certificate is already present on the drive.")
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }

                                Label {
                                    visible: premiumCertificatePath.length === 0
                                    text: qsTr("Keep the existing certificate or select a new one to replace it.")
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

    DeviceSelectionPage {
        anchors.fill: parent
        visible: selectingTarget
        enabled: visible
        z: 2
        deviceModel: driveListModel
        title: qsTr("Choose configuration storage")
        subtitle: qsTr("Select the OpenHD SD card or USB storage whose settings you want to edit.")
        onDeviceSelected: {
            selectDstItem(device)
            selectingTarget = false
            imageWriter.stopDriveListPolling()
        }
        onBackRequested: {
            selectingTarget = false
            imageWriter.stopDriveListPolling()
        }
        onRefreshRequested: {
            imageWriter.stopDriveListPolling()
            imageWriter.startDriveListPolling()
        }
    }

    function returnToOverview() {
        selectingTarget = false
        imageWriter.stopDriveListPolling()
    }

    MsgPopup {
        id: msgpopup
        onClosed: {
            if (returnHomeAfterPopupClose) {
                returnHomeAfterPopupClose = false
                navigateBack()
            }
        }
    }

    FileDialog {
        id: qopenhdConfDialog
        title: qsTr("Select QOpenHD.conf")
        nameFilters: [qsTr("QOpenHD.conf (*.conf)"), qsTr("All files (*)")]
        selectExisting: true
        onAccepted: {
            var selectedUrl = qopenhdConfDialog.fileUrl
            if (!selectedUrl || selectedUrl.toString().length === 0) {
                if (qopenhdConfDialog.fileUrls && qopenhdConfDialog.fileUrls.length > 0) {
                    selectedUrl = qopenhdConfDialog.fileUrls[0]
                }
            }
            if (selectedUrl && selectedUrl.toString) {
                var selectedStr = selectedUrl.toString()
                if (selectedStr.startsWith("file:")) {
                    qopenhdConfPath = normalizeLocalFilePath(selectedUrl.toLocalFile ? selectedUrl.toLocalFile() : selectedStr)
                } else {
                    qopenhdConfPath = normalizeLocalFilePath(selectedStr)
                }
            }
        }
    }

    FileDialog {
        id: premiumCertificateDialog
        title: qsTr("Select premium certificate")
        nameFilters: [qsTr("OpenHD certificate (*.ohdcert)"), qsTr("All files (*)")]
        selectExisting: true
        onAccepted: {
            var selectedUrl = premiumCertificateDialog.fileUrl
            if (!selectedUrl || selectedUrl.toString().length === 0) {
                if (premiumCertificateDialog.fileUrls && premiumCertificateDialog.fileUrls.length > 0) {
                    selectedUrl = premiumCertificateDialog.fileUrls[0]
                }
            }
            if (selectedUrl && selectedUrl.toString) {
                var selectedStr = selectedUrl.toString()
                var selectedPath = ""
                if (selectedStr.startsWith("file:")) {
                    selectedPath = normalizeLocalFilePath(selectedUrl.toLocalFile ? selectedUrl.toLocalFile() : selectedStr)
                } else {
                    selectedPath = normalizeLocalFilePath(selectedStr)
                }

                var validationError = imageWriter.validatePremiumCertificate(selectedPath)
                if (validationError && validationError.length > 0) {
                    premiumCertificatePath = ""
                    onError(qsTr("Premium certificate is invalid: %1").arg(validationError))
                } else {
                    premiumCertificatePath = selectedPath
                }
            }
        }
    }

    function normalizeLocalFilePath(value) {
        if (!value)
            return ""
        if (typeof value !== "string" && value.toString)
            value = value.toString()
        if (value.startsWith("file:")) {
            value = decodeURIComponent(value.replace(/^file:\/\//, ""))
            if (value.startsWith("/") && value.length > 2 && value[2] === ":") {
                value = value.substring(1)
            }
        }
        return value
    }

    function selectDstItem(d) {
        if (d.isReadOnly) {
            onError(qsTr("SD card is write protected.<br>Push the lock switch on the left side of the card upwards, and try again."))
            return
        }

        selectingTarget = false
        imageWriter.stopDriveListPolling()
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
        returnHomeAfterPopupClose = false
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

    function premiumCertificateRelativePath() {
        if (settingsMap.premiumCertificate && settingsMap.premiumCertificate.file)
            return settingsMap.premiumCertificate.file
        return "openhd/premium_certificate.ohdcert"
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

    function secondaryCameraValueForSelection(cameraSelection) {
        if (!cameraSelection || cameraSelection.length === 0)
            return ""

        var options = settingsMap.camera && settingsMap.camera.secondaryOptions ? settingsMap.camera.secondaryOptions : []
        for (var i = 0; i < options.length; i++) {
            if (options[i].id === cameraSelection)
                return options[i].valueWritten || ""
        }

        return ""
    }

    function cameraValueForSelection(cameraSelection) {
        var secondaryCameraValue = secondaryCameraValueForSelection(cameraSelection)
        if (secondaryCameraValue && secondaryCameraValue.length > 0)
            return secondaryCameraValue

        var group = getCameraGroupForSelection()
        if (!group || !group.vendors)
            return ""

        for (var i = 0; i < group.vendors.length; i++) {
            var vendor = group.vendors[i]
            if (!vendor || !vendor.options)
                continue

            for (var optIdx = 0; optIdx < vendor.options.length; optIdx++) {
                var opt = vendor.options[optIdx]
                if (opt && opt.id === cameraSelection) {
                    return opt.valueWritten || ""
                }
            }
        }
        return ""
    }

    function isRpiCsiCamera(cameraSelection) {
        var cameraType = parseInt(cameraValueForSelection(cameraSelection))
        return cameraType >= 20 && cameraType <= 69
    }

    function setCameraFromValue(encodedValue, cameraSlot) {
        var normalizedEncodedValue = encodedValue !== undefined && encodedValue !== null ? encodedValue.toString() : ""
        if (normalizedEncodedValue === "1")
            normalizedEncodedValue = "10"

        if (cameraSlot === "camera2") {
            camera2 = ""
            var secondaryOptions = settingsMap.camera && settingsMap.camera.secondaryOptions ? settingsMap.camera.secondaryOptions : []
            for (var secondaryIdx = 0; secondaryIdx < secondaryOptions.length; secondaryIdx++) {
                if ((secondaryOptions[secondaryIdx].valueWritten || "") === normalizedEncodedValue) {
                    camera2 = secondaryOptions[secondaryIdx].id
                    break
                }
            }
            if (!camera2 || camera2.length === 0) {
                var secondaryGroup = getCameraGroupForSelection()
                if (secondaryGroup && secondaryGroup.secondaryCsi && secondaryGroup.vendors) {
                    for (var vendorIdx = 0; vendorIdx < secondaryGroup.vendors.length; vendorIdx++) {
                        var vendorOptions = secondaryGroup.vendors[vendorIdx].options || []
                        for (var optIdx = 0; optIdx < vendorOptions.length; optIdx++) {
                            if ((vendorOptions[optIdx].valueWritten || "") === normalizedEncodedValue) {
                                camera2 = vendorOptions[optIdx].id
                                break
                            }
                        }
                        if (camera2 && camera2.length > 0)
                            break
                    }
                }
            }
            cameraLayout.rebuildSecondaryCameraOptions()
            return
        }

        var commonOptions = settingsMap.camera && settingsMap.camera.secondaryOptions ? settingsMap.camera.secondaryOptions : []
        for (var commonIdx = 0; commonIdx < commonOptions.length; commonIdx++) {
            if ((commonOptions[commonIdx].valueWritten || "") === normalizedEncodedValue) {
                camera = commonOptions[commonIdx].id
                cameraLayout.rebuildVendors()
                return
            }
        }

        var group = getCameraGroupForSelection()
        if (!group || !group.vendors)
            return

        for (var i = 0; i < group.vendors.length; i++) {
            var vendor = group.vendors[i]
            if (!vendor || !vendor.options)
                continue

            for (var optIdx = 0; optIdx < vendor.options.length; optIdx++) {
                var opt = vendor.options[optIdx]
                if (opt && opt.valueWritten === normalizedEncodedValue) {
                    camera = opt.id
                    cameraLayout.selectedVendor = vendor
                    console.log("[Configure] Camera loaded from drive:", cameraSlot, opt.id)
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
        camera2 = ""
        cameraResolution = ""
        camera2Resolution = ""
        cameraPort = "cam1"
        camera2Port = "cam0"
        ipCameraAddress = "192.168.144.108"
        ipCameraPipeline = "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
        camera2IpCameraAddress = "192.168.144.108"
        camera2IpCameraPipeline = "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
        ipCameraBitrate = 2
        displayForceMode = false
        displayWidth = 1920
        displayHeight = 1080
        displayRefreshHz = 60
        mode = ""
        qopenhdConfPresent = false
        premiumCertificatePresent = false

        var settingsJson = imageWriter.readTextFile(drivePath("settings.json"))
        var settingsObj = {}
        if (settingsJson && settingsJson.length > 0) {
            try {
                settingsObj = JSON.parse(settingsJson)
            } catch (e) {
                console.log("[Configure] Error parsing settings.json:", e)
            }
        }

        if (settingsObj.role === "air") {
            bootType = "Air"
        } else if (settingsObj.role === "ground") {
            bootType = "Ground"
        } else if (settingsMap.bootType && settingsMap.bootType.options && settingsMap.bootType.options.length > 0) {
            bootType = settingsMap.bootType.options[0].id
        }

        if (settingsObj.sbc) {
            sbc = settingsObj.sbc
        } else if (settingsMap.sbc && settingsMap.sbc.options && settingsMap.sbc.options.length > 0) {
            sbc = settingsMap.sbc.options[0].id
        }

        if (settingsObj.debug) {
            mode = "debug"
            setDebug.checked = true
        } else {
            mode = ""
            setDebug.checked = false
        }

        if (settingsObj.camera_resolution_fps !== undefined && settingsObj.camera_resolution_fps !== null) {
            cameraResolution = settingsObj.camera_resolution_fps.toString()
        } else {
            cameraResolution = ""
        }

        if (settingsObj.camera2_resolution_fps !== undefined && settingsObj.camera2_resolution_fps !== null) {
            camera2Resolution = settingsObj.camera2_resolution_fps.toString()
        } else {
            camera2Resolution = ""
        }
        cameraPort = settingsObj.camera_port === "cam0" ? "cam0" : "cam1"
        camera2Port = settingsObj.camera2_port === "cam1" ? "cam1" : "cam0"

        if (settingsObj.ip_camera_address) {
            ipCameraAddress = settingsObj.ip_camera_address.toString()
        }
        if (settingsObj.ip_camera_pipeline) {
            ipCameraPipeline = settingsObj.ip_camera_pipeline.toString()
        }
        if (settingsObj.camera2_ip_camera_address) {
            camera2IpCameraAddress = settingsObj.camera2_ip_camera_address.toString()
        }
        if (settingsObj.camera2_ip_camera_pipeline) {
            camera2IpCameraPipeline = settingsObj.camera2_ip_camera_pipeline.toString()
        }
        var loadedIpCameraBitrate = parseInt(settingsObj.ip_camera_bitrate_mbits)
        if (loadedIpCameraBitrate >= 1 && loadedIpCameraBitrate <= 20) {
            ipCameraBitrate = loadedIpCameraBitrate
        }
        displayForceMode = settingsObj.display_force_mode === true
        var loadedDisplayWidth = parseInt(settingsObj.display_width)
        var loadedDisplayHeight = parseInt(settingsObj.display_height)
        var loadedDisplayRefreshHz = parseInt(settingsObj.display_refresh_hz)
        displayWidth = loadedDisplayWidth >= 320 && loadedDisplayWidth <= 7680 ? loadedDisplayWidth : 1920
        displayHeight = loadedDisplayHeight >= 240 && loadedDisplayHeight <= 4320 ? loadedDisplayHeight : 1080
        displayRefreshHz = loadedDisplayRefreshHz >= 20 && loadedDisplayRefreshHz <= 240 ? loadedDisplayRefreshHz : 60

        if (settingsObj.camera) {
            setCameraFromValue(settingsObj.camera, "camera")
        } else {
            camera = ""
        }

        if (settingsObj.camera2) {
            setCameraFromValue(settingsObj.camera2, "camera2")
        } else {
            camera2 = ""
        }

        if (settingsObj.language !== undefined) {
            language = settingsObj.language
        } else {
            language = imageWriter.getValue("language")
        }

        if (settingsObj.token !== undefined) {
            token = settingsObj.token
        } else {
            token = imageWriter.getValue("token")
        }

        qopenhdConfPresent = imageWriter.fileExists(drivePath(qopenhdConfRelativePath()))
        premiumCertificatePresent = imageWriter.fileExists(drivePath(premiumCertificateRelativePath()))

        console.log("[Configure] Loaded settings -> bootType:", bootType, "sbc:", sbc, "camera:", camera, "camera2:", camera2, "cameraResolution:", cameraResolution, "camera2Resolution:", camera2Resolution)
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

        var settingsObj = {}
        if (bootType === "Air") {
            settingsObj.role = "air"
        } else if (bootType === "Ground") {
            settingsObj.role = "ground"
            settingsObj.display_force_mode = displayForceMode
            if (displayForceMode) {
                settingsObj.display_width = displayWidth
                settingsObj.display_height = displayHeight
                settingsObj.display_refresh_hz = displayRefreshHz
                settingsObj.display_connector = "HDMI-A-1"
            }
        }

        if (sbc && sbc.length > 0) {
            settingsObj.sbc = sbc
        }

        if (mode === "debug") {
            settingsObj.debug = true
        }

        var camValue = cameraValueForSelection(camera)
        if (camValue && camValue.length > 0) {
            settingsObj.camera = camValue
        }

        var cam2Value = cameraValueForSelection(camera2)
        if (!cam2Value || cam2Value.length === 0) {
            cam2Value = "255"
        }
        settingsObj.camera2 = cam2Value

        if (cameraResolution && cameraResolution.length > 0) {
            settingsObj.camera_resolution_fps = cameraResolution
        }

        if (cam2Value !== "255" && camera2Resolution && camera2Resolution.length > 0) {
            settingsObj.camera2_resolution_fps = camera2Resolution
        }
        if (sbc === "rpi" && parseInt(camValue) >= 20 && parseInt(camValue) <= 69)
            settingsObj.camera_port = cameraPort
        if (sbc === "rpi" && parseInt(cam2Value) >= 20 && parseInt(cam2Value) <= 69)
            settingsObj.camera2_port = camera2Port

        if (camValue === "3") {
            settingsObj.ip_camera_address = ipCameraAddress.trim()
            settingsObj.ip_camera_pipeline = ipCameraPipeline.trim()
        }
        if (cam2Value === "3") {
            settingsObj.camera2_ip_camera_address = camera2IpCameraAddress.trim()
            settingsObj.camera2_ip_camera_pipeline = camera2IpCameraPipeline.trim()
        }
        if (camValue === "3" || cam2Value === "3") {
            settingsObj.ip_camera_bitrate_mbits = Math.max(1, Math.min(20, ipCameraBitrate))
        }

        settingsObj.language = language ? language : ""
        settingsObj.token = token ? token : ""

        var jsonString = JSON.stringify(settingsObj, null, 4)
        if (imageWriter.writeTextFile(drivePath("settings.json"), jsonString)) {
            // Clean up old files if they exist, just in case
            imageWriter.removeFile(drivePath("air.txt"))
            imageWriter.removeFile(drivePath("ground.txt"))
            imageWriter.removeFile(drivePath("debug.txt"))
            imageWriter.removeFile(drivePath("camera1.txt"))
            imageWriter.removeFile(drivePath("camera2.txt"))
            // We don't easily know which SBC file might exist, so we might skip cleaning those up
            // or iterate through sbc options to delete them. For now, assuming fresh flash or JSON usage.
             if (settingsMap.sbc && settingsMap.sbc.options) {
                for (var i = 0; i < settingsMap.sbc.options.length; i++) {
                    var opt = settingsMap.sbc.options[i]
                    imageWriter.removeFile(drivePath(opt.file))
                }
            }
        } else {
             onError(qsTr("Failed to write settings.json to the drive."))
             return
        }

        qopenhdConfPath = normalizeLocalFilePath(qopenhdConfPath)
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

        premiumCertificatePath = normalizeLocalFilePath(premiumCertificatePath)
        if (premiumCertificatePath && premiumCertificatePath.length > 0) {
            var certificateError = imageWriter.validatePremiumCertificate(premiumCertificatePath)
            if (certificateError && certificateError.length > 0) {
                onError(qsTr("Premium certificate is invalid: %1").arg(certificateError))
                return
            }
            var certificateTarget = drivePath(premiumCertificateRelativePath())
            if (!imageWriter.copyFile(premiumCertificatePath, certificateTarget)) {
                onError(qsTr("Failed to copy premium certificate to the drive."))
                return
            }
            premiumCertificatePresent = true
        } else {
            premiumCertificatePresent = imageWriter.fileExists(drivePath(premiumCertificateRelativePath()))
        }

        imageWriter.setSetting("bootType", bootType)
        imageWriter.setSetting("sbc", sbc)
        imageWriter.setSetting("camera", camera)
        imageWriter.setSetting("camera2", camera2)
        imageWriter.setSetting("cameraResolution", cameraResolution)
        imageWriter.setSetting("camera2Resolution", camera2Resolution)
        imageWriter.setSetting("cameraPort", cameraPort)
        imageWriter.setSetting("camera2Port", camera2Port)
        imageWriter.setSetting("ipCameraAddress", ipCameraAddress)
        imageWriter.setSetting("ipCameraPipeline", ipCameraPipeline)
        imageWriter.setSetting("camera2IpCameraAddress", camera2IpCameraAddress)
        imageWriter.setSetting("camera2IpCameraPipeline", camera2IpCameraPipeline)
        imageWriter.setSetting("ipCameraBitrate", ipCameraBitrate)
        imageWriter.setSetting("displayForceMode", displayForceMode)
        imageWriter.setSetting("displayWidth", displayWidth)
        imageWriter.setSetting("displayHeight", displayHeight)
        imageWriter.setSetting("displayRefreshHz", displayRefreshHz)
        imageWriter.setSetting("mode", mode)
        imageWriter.setSetting("qopenhdConfPath", qopenhdConfPath)
        imageWriter.setSetting("premiumCertificatePath", premiumCertificatePath)
        imageWriter.setSetting("language", language)
        imageWriter.setSetting("token", token)

        console.log("[Configure] Settings written: bootType", bootType, "sbc", sbc, "camera", camera, "camera2", camera2, "cameraResolution", cameraResolution, "camera2Resolution", camera2Resolution)
        msgpopup.title = qsTr("Settings written")
        msgpopup.text = qsTr("Settings were written to <b>%1</b>.").arg(selectedDevice)
        msgpopup.continueButton = true
        msgpopup.detailsButton = false
        msgpopup.configureButton = false
        msgpopup.closeButton = false
        msgpopup.quitButton = false
        msgpopup.yesButton = false
        msgpopup.noButton = false
        returnHomeAfterPopupClose = true
        msgpopup.openPopup()
    }
}
