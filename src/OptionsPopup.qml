/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2021 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2
import Qt.labs.settings 1.0
import QtQuick.Dialogs 1.3
import "qmlcomponents"

Popup {
    id: popup
    //x: 62
    x: (parent.width-width)/2
    y: 10
    //width: parent.width-125
    width: popupbody.implicitWidth+60
    height: parent.height-20
    padding: 0
    closePolicy: Popup.CloseOnEscape
    property bool initialized: false

    property var settingsMap: ({})
    property bool settingsMapLoaded: false

    // refactored settings
    property string bootType
    property string fileName
    property string sbc
    property string camera
    property string camera2
    property string cameraResolution
    property string camera2Resolution
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
    property string mode
    property string hotSpot
    property string beep
    property string eject
    property bool rock3
    property bool rock5
    property bool rpi
    property bool supportsAir: true
    property bool supportsGround: true
    property bool useSettings:true
    property string qopenhdConfPath: ""
    property string premiumCertificatePath: ""
    property string premiumCertificateError: ""

    // background of title
    Rectangle {
        color: "#f5f5f5"
        anchors.right: parent.right
        anchors.top: parent.top
        height: 35
        width: parent.width
    }
    // line under title
    Rectangle {
        color: "#afafaf"
        width: parent.width
        y: 35
        implicitHeight: 1
    }

    ColumnLayout {
        spacing: 10
        anchors.fill: parent

        Text {
            id: popupheader
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
            Layout.topMargin: 10
            font.family: roboto.name
            font.bold: true
            text: qsTr("Advanced options")
        }

        ScrollView {
            id: popupbody
            font.family: roboto.name
            //Layout.maximumWidth: popup.width-30
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 25
            Layout.topMargin: 10
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOn

            ColumnLayout {
                GroupBox {
                    label: RowLayout {
                        Label {
                            text: parent.parent.title
                        }
                    }

                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: -10

                        Repeater {
                            id: bootRepeater
                            model: settingsMap.bootType && settingsMap.bootType.options ? settingsMap.bootType.options.filter(function(option) {
                                return option.id && option.id.length > 0 && ((option.id === "Air" && supportsAir) || (option.id === "Ground" && supportsGround))
                            }) : []
                            delegate: ImCheckBox {
                                property var option: modelData
                                text: qsTr("Set SBC to %1").arg(option ? option.id : "")
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
                                    }
                                }
                            }
                        }
                    }
                }
                GroupBox {
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
                        Label {
                            text: qsTr("Use this when a monitor is not detected reliably. Automatic EDID detection remains the default.")
                            wrapMode: Text.WordWrap
                            Layout.maximumWidth: 520
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
                GroupBox {
                    title: qsTr("Camera Settings")
                    id: cameraSettings
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 8
                        Repeater {
                            id: cameraGroupRepeater
                            model: settingsMap.camera && settingsMap.camera.sbcGroups ? settingsMap.camera.sbcGroups : []
                            delegate: GroupBox {
                                property var groupData: modelData
                                title: qsTr("Camera Settings")
                                Layout.fillWidth: true
                                visible: groupData && groupData.sbc && groupData.sbc.indexOf(sbc) !== -1 && bootType === groupData.bootTypeRequired

                                ColumnLayout {
                                    id: cameraGroup
                                    spacing: 8

                                    property var vendorList: (groupData && groupData.vendors ? groupData.vendors : []).concat(
                                        settingsMap.camera && settingsMap.camera.commonVendors ? settingsMap.camera.commonVendors : [])
                                    property var selectedVendor: vendorList.length > 0 ? vendorList[0] : null

                                    ListModel {
                                        id: vendorModel
                                    }

                                    ComboBox {
                                        id: vendorSelector
                                        visible: vendorModel.count > 1
                                        textRole: "displayName"
                                        model: vendorModel
                                        Layout.minimumWidth: 200
                                        Layout.maximumHeight: 40
                                        onCurrentIndexChanged: {
                                            if (vendorModel.count > 0) {
                                                var modelVendor = vendorModel.get(currentIndex)
                                                if (modelVendor && modelVendor.vendorIndex >= 0 && modelVendor.vendorIndex < cameraGroup.vendorList.length) {
                                                    cameraGroup.selectedVendor = cameraGroup.vendorList[modelVendor.vendorIndex]
                                                    cameraGroup.rebuildCameraOptions()
                                                }
                                            }
                                        }
                                    }

                                    ListModel {
                                        id: cameraOptionsModel
                                    }

                                    ListModel {
                                        id: camera2OptionsModel
                                    }

                                    ListModel {
                                        id: cameraResolutionOptionsModel
                                    }

                                    ListModel {
                                        id: camera2ResolutionOptionsModel
                                    }

                                    GridLayout {
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 6
                                        Layout.topMargin: 4
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
                                            Layout.minimumWidth: 200
                                            Layout.maximumHeight: 40
                                            onCurrentIndexChanged: {
                                                if (cameraOptionsModel.count > 0) {
                                                    var selectedCamera = cameraOptionsModel.get(currentIndex).displayText
                                                    if (selectedCamera !== "NONE") {
                                                        camera = selectedCamera
                                                    } else {
                                                        camera = ""
                                                    }
                                                    cameraGroup.rebuildPrimaryResolutionOptions()
                                                }
                                            }
                                        }

                                        ComboBox {
                                            id: cameraResolutionSelector
                                            textRole: "label"
                                            model: cameraResolutionOptionsModel
                                            Layout.minimumWidth: 200
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
                                            Layout.minimumWidth: 200
                                            Layout.maximumHeight: 40
                                            onCurrentIndexChanged: {
                                                if (camera2OptionsModel.count > 0) {
                                                    var selectedSecondary = camera2OptionsModel.get(currentIndex)
                                                    camera2 = selectedSecondary && selectedSecondary.cameraId ? selectedSecondary.cameraId : ""
                                                    cameraGroup.rebuildSecondaryResolutionOptions()
                                                }
                                            }
                                        }

                                        ComboBox {
                                            id: camera2ResolutionSelector
                                            textRole: "label"
                                            model: camera2ResolutionOptionsModel
                                            Layout.minimumWidth: 200
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

                                    function secondaryCameraValueForSelection(selection) {
                                        if (!selection || selection.length === 0)
                                            return ""

                                        var options = settingsMap.camera && settingsMap.camera.secondaryOptions ? settingsMap.camera.secondaryOptions : []
                                        for (var i = 0; i < options.length; i++) {
                                            if (options[i].id === selection)
                                                return options[i].valueWritten || ""
                                        }

                                        if (groupData.secondaryCsi && groupData.vendors) {
                                            for (var vendorIdx = 0; vendorIdx < groupData.vendors.length; vendorIdx++) {
                                                var vendorOptions = groupData.vendors[vendorIdx].options || []
                                                for (var optIdx = 0; optIdx < vendorOptions.length; optIdx++) {
                                                    if (vendorOptions[optIdx].id === selection)
                                                        return vendorOptions[optIdx].valueWritten || ""
                                                }
                                            }
                                        }

                                        return ""
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

                                        var encodedCamera2Value = secondaryCameraValueForSelection(camera2)

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

                                        if (groupData.secondaryCsi && groupData.vendors) {
                                            for (var vendorIdx = 0; vendorIdx < groupData.vendors.length; vendorIdx++) {
                                                var vendorOptions = groupData.vendors[vendorIdx].options || []
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
                                        cameraOptionsModel.append({ displayText: "NONE" })

                                        if (cameraGroup.selectedVendor && cameraGroup.selectedVendor.options) {
                                            for (var i = 0; i < cameraGroup.selectedVendor.options.length; i++) {
                                                var option = cameraGroup.selectedVendor.options[i]
                                                cameraOptionsModel.append({ displayText: option.id, value: option.valueWritten })
                                            }
                                        }

                                        console.log("[OptionsPopup] camera options rebuilt for vendor", cameraGroup.selectedVendor ? cameraGroup.selectedVendor.id : "none", "->", cameraOptionsModel.count, "entries")

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
                                        for (var i = 0; i < cameraGroup.vendorList.length; i++) {
                                            var vendor = cameraGroup.vendorList[i]
                                            vendorModel.append({ displayName: vendor.displayName, vendorIndex: i })
                                        }
                                        console.log("[OptionsPopup] vendor list rebuilt for boot", bootType, "sbc", sbc, "->", vendorModel.count, "vendors")
                                        if (vendorModel.count > 0) {
                                            var index = vendorSelector.currentIndex >= 0 ? vendorSelector.currentIndex : 0
                                            var foundVendor = false
                                            for (var vendorIdx = 0; vendorIdx < cameraGroup.vendorList.length; vendorIdx++) {
                                                var vendorCandidate = cameraGroup.vendorList[vendorIdx]
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
                                            cameraGroup.selectedVendor = cameraGroup.vendorList[index]
                                        }
                                        cameraGroup.rebuildCameraOptions()
                                    }

                                    Component.onCompleted: rebuildVendors()
                                }
                            }
                        }

                        GroupBox {
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

                        GroupBox {
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
                                    Layout.minimumWidth: 360
                                    maximumLength: 15
                                    text: ipCameraAddress
                                    placeholderText: "192.168.144.108"
                                    onEditingFinished: ipCameraAddress = text.trim()
                                }
                                Label { text: qsTr("Primary source pipeline"); visible: camera === "IP-CAMERA" }
                                TextField {
                                    visible: camera === "IP-CAMERA"
                                    Layout.minimumWidth: 360
                                    maximumLength: 127
                                    text: ipCameraPipeline
                                    placeholderText: "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
                                    onEditingFinished: ipCameraPipeline = text.trim()
                                }

                                Label { text: qsTr("Secondary camera IP"); visible: camera2 === "IP-CAMERA" }
                                TextField {
                                    visible: camera2 === "IP-CAMERA"
                                    Layout.minimumWidth: 360
                                    maximumLength: 15
                                    text: camera2IpCameraAddress
                                    placeholderText: "192.168.144.108"
                                    onEditingFinished: camera2IpCameraAddress = text.trim()
                                }
                                Label { text: qsTr("Secondary source pipeline"); visible: camera2 === "IP-CAMERA" }
                                TextField {
                                    visible: camera2 === "IP-CAMERA"
                                    Layout.minimumWidth: 360
                                    maximumLength: 127
                                    text: camera2IpCameraPipeline
                                    placeholderText: "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
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
                    }
                }
                GroupBox {
                    title: qsTr("Misc Settings")
                    id: miscSettings
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: -10

                        ImCheckBox {
                            id: setDebug
                            visible: !!(settingsMap.mode && settingsMap.mode.options && settingsMap.mode.options.length > 0)
                            text: settingsMap.mode && settingsMap.mode.options && settingsMap.mode.options.length > 0 ? qsTr(settingsMap.mode.options[0].id || "Debug Mode") : qsTr("Debug Mode")
                            onCheckedChanged: {
                                if (checked) {
                                    mode = "debug";
                                }
                            }
                        }

                    TextField {
                            id: textField
                            visible: imageWriter.getValue("developer") !== "Kugelrund"
                            onTextChanged: {
                                saveButton.visible = text === "Kugelrund";
                            }
                        }

                        Button {
                            id: saveButton
                            text: "Use Dev Images"
                            visible: false
                            onClicked: {
                                imageWriter.setSetting("developer","Kugelrund");
                                imageWriter.makeDeveloper();
                            }
                        }

                        Button {
                            id: userButton
                            text: "Use Normal Images"
                            visible: imageWriter.getValue("developer") == "Kugelrund"
                            onClicked: {
                                imageWriter.setSetting("developer","");
                                imageWriter.makeUser();
                            }
                        }

                        ImCheckBox {
                            id: setWifiHotspot
                            visible: !!(settingsMap.hotSpot && settingsMap.hotSpot.options && settingsMap.hotSpot.options.length > 0)
                            text: settingsMap.hotSpot && settingsMap.hotSpot.options && settingsMap.hotSpot.options.length > 0 ? qsTr(settingsMap.hotSpot.options[0].id || "WifiHotspot") : qsTr("WifiHotspot")
                            onCheckedChanged: {
                                if (checked) {
                                    hotSpot = "wifi";
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
                            visible: qopenhdConfPath.length === 0
                            text: qsTr("Existing QOpenHD.conf on the target will be kept when no file is selected.")
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }

                GroupBox {
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
                                onClicked: {
                                    premiumCertificatePath = ""
                                    premiumCertificateError = ""
                                }
                            }
                        }

                        Label {
                            visible: premiumCertificateError.length > 0
                            text: premiumCertificateError
                            color: "#C0392B"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Label {
                            visible: premiumCertificatePath.length === 0 && premiumCertificateError.length === 0
                            text: qsTr("Existing premium certificate on the target will be kept when no file is selected.")
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter | Qt.AlignBottom
            Layout.bottomMargin: 6
            spacing: 16

            ImButton {
                text: qsTr("SAVE")
                onClicked: {
                    applySettings()
                    popup.close()
                }
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }

            Text { text: " " }
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
                    premiumCertificateError = qsTr("Premium certificate is invalid: %1").arg(validationError)
                } else {
                    premiumCertificatePath = selectedPath
                    premiumCertificateError = ""
                }
            }
        }
    }

    function initialize() {
        console.log("[OptionsPopup] initialize() called")
        loadSettingsMap()
        var settings = imageWriter.getSavedCustomizationSettings()

        // initialise settings
        bootType = imageWriter.getValue("bootType")
        if (!bootType && settingsMap.bootType && settingsMap.bootType.options && settingsMap.bootType.options.length > 0) {
            bootType = settingsMap.bootType.options[0].id
        }
        console.log("[OptionsPopup] bootType:", bootType)
        fileName = imageWriter.srcFileName();
        sbc = imageWriter.getValue("sbc")
        camera= imageWriter.getValue("camera")
        camera2 = imageWriter.getValue("camera2")
        cameraResolution = imageWriter.getValue("cameraResolution")
        camera2Resolution = imageWriter.getValue("camera2Resolution")
        cameraPort = imageWriter.getValue("cameraPort") === "cam0" ? "cam0" : "cam1"
        camera2Port = imageWriter.getValue("camera2Port") === "cam1" ? "cam1" : "cam0"
        ipCameraAddress = imageWriter.getValue("ipCameraAddress") || "192.168.144.108"
        ipCameraPipeline = imageWriter.getValue("ipCameraPipeline") || "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
        camera2IpCameraAddress = imageWriter.getValue("camera2IpCameraAddress") || "192.168.144.108"
        camera2IpCameraPipeline = imageWriter.getValue("camera2IpCameraPipeline") || "rtspsrc location=rtsp://{IP}:554/stream=0 latency=0 ! rtph264depay"
        var savedIpCameraBitrate = parseInt(imageWriter.getValue("ipCameraBitrate"))
        ipCameraBitrate = savedIpCameraBitrate >= 1 && savedIpCameraBitrate <= 20 ? savedIpCameraBitrate : 2
        displayForceMode = imageWriter.getBoolSetting("displayForceMode")
        var savedDisplayWidth = parseInt(imageWriter.getValue("displayWidth"))
        var savedDisplayHeight = parseInt(imageWriter.getValue("displayHeight"))
        var savedDisplayRefreshHz = parseInt(imageWriter.getValue("displayRefreshHz"))
        displayWidth = savedDisplayWidth >= 320 && savedDisplayWidth <= 7680 ? savedDisplayWidth : 1920
        displayHeight = savedDisplayHeight >= 240 && savedDisplayHeight <= 4320 ? savedDisplayHeight : 1080
        displayRefreshHz = savedDisplayRefreshHz >= 20 && savedDisplayRefreshHz <= 240 ? savedDisplayRefreshHz : 60
        mode = imageWriter.getValue("mode")
        hotSpot = imageWriter.getValue("hotSpot")
        beep = imageWriter.getBoolSetting("beep")
        eject = imageWriter.getBoolSetting("eject")
        qopenhdConfPath = normalizeLocalFilePath(imageWriter.getValue("qopenhdConfPath"))
        premiumCertificatePath = normalizeLocalFilePath(imageWriter.getValue("premiumCertificatePath"))
        premiumCertificateError = ""

        // set session settings
        if (mode) {
            setDebug.checked=true
        }
        else{
            setDebug.checked=false
        }
        if (hotSpot) {
            setWifiHotspot.checked=true
        }
        else{
            setWifiHotspot.checked=false
        }

        // Detect the platform and the role capabilities from all current image
        // naming schemes. Lite/minimal images intentionally have no Air stack.
        imageWriter.setSetting("fileName", fileName)
        console.log("[OptionsPopup] src file:", fileName)
        var normalizedFileName = fileName.toLowerCase()
        supportsAir = normalizedFileName.indexOf("lite") === -1 && normalizedFileName.indexOf("minimal") === -1
        supportsGround = normalizedFileName.indexOf("x20") === -1
        if (!supportsGround)
            bootType = "Air"
        else if (!supportsAir)
            bootType = "Ground"

        if (normalizedFileName.includes("rock5a") || normalizedFileName.includes("rock-5a")) {
            imageWriter.setSetting("sbc", "rock-5a");
            sbc = "rock-5a"
            rpi=false; rock5=true; rock3=false;
        }
        else if (normalizedFileName.includes("rock5b") || normalizedFileName.includes("rock-5b")) {
            imageWriter.setSetting("sbc", "rock-5b");
            sbc = "rock-5b"
            rpi=false; rock5=true; rock3=false;
        }
        else if (normalizedFileName.includes("zero3") || normalizedFileName.includes("zero-3")) {
            imageWriter.setSetting("sbc", "zero3w");
            sbc = "zero3w"
            rpi=false; rock5=false; rock3=true;
        }
        else if (normalizedFileName.includes("radxa-cm5") || normalizedFileName.includes("radxa_cm5")) {
            sbc = "radxa-cm5"; rpi=false; rock5=true; rock3=false;
        }
        else if (normalizedFileName.includes("radxa-cm3") || normalizedFileName.includes("radxa_cm3")) {
            imageWriter.setSetting("sbc", "radxa-cm3");
            sbc = "radxa-cm3"
            rpi=false; rock5=false; rock3=true;
        }
        else if (normalizedFileName.includes("qrb5165")) {
            sbc = "qrb5165"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("qcs405")) {
            sbc = "qcs405"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("openipc")) {
            sbc = "openipc"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("rv1103") || normalizedFileName.includes("rv1106") || normalizedFileName.includes("rv1126") || normalizedFileName.includes("luckfox")) {
            sbc = "rockchip-rv"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("orqa")) {
            sbc = "orqa"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("x20")) {
            sbc = "x20"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("x21")) {
            sbc = "x21"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("cubie") || normalizedFileName.includes("a733")) {
            sbc = "cubie"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("xavier") || normalizedFileName.includes("jetson")) {
            sbc = "nvidia-xavier"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("uvx") || normalizedFileName.includes("uvx-mod")) {
            sbc = "uvx"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("imx8") || normalizedFileName.includes("nxp")) {
            sbc = "nxp-imx8"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("x86") || normalizedFileName.includes("amd64")) {
            sbc = "x86"; rpi=false; rock5=false; rock3=false;
        }
        else if (normalizedFileName.includes("raspberry") || normalizedFileName.includes("rpi") || normalizedFileName.includes("image-pi") || normalizedFileName.includes("image_pi")) {
            imageWriter.setSetting("sbc", "rpi");
            sbc = "rpi"
            rpi=true;
            rock5=false;
            rock3=false;
        }
        else{
           imageWriter.setSetting("sbc", "unknown");
           sbc = "unknown"
           rpi=false;
           rock5=false;
           rock3=false;
        }
        imageWriter.setSetting("sbc", sbc)
        imageWriter.setSetting("bootType", bootType)

        console.log("[OptionsPopup] detected SBC:", sbc)
        console.log("[OptionsPopup] saved camera:", camera)
        console.log("[OptionsPopup] saved camera2:", camera2)
        console.log("[OptionsPopup] saved cameraResolution:", cameraResolution)
        console.log("[OptionsPopup] saved camera2Resolution:", camera2Resolution)

        initialized = true
    }

    function openPopup() {
        initialize()
        open()
        popupbody.forceActiveFocus()
    }

    function applySettings()
    {
        qopenhdConfPath = normalizeLocalFilePath(qopenhdConfPath)
        premiumCertificatePath = normalizeLocalFilePath(premiumCertificatePath)
        if (premiumCertificatePath.length > 0) {
            var certificateError = imageWriter.validatePremiumCertificate(premiumCertificatePath)
            if (certificateError && certificateError.length > 0) {
                premiumCertificatePath = ""
                premiumCertificateError = qsTr("Premium certificate is invalid: %1").arg(certificateError)
            }
        }

        imageWriter.setSetting("bootType", bootType)
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
        imageWriter.setSetting("hotSpot" , hotSpot)
        imageWriter.setSetting("beep", beep)
        imageWriter.setSetting("eject", eject)
        imageWriter.setSetting("useSettings", useSettings)
        imageWriter.setSetting("qopenhdConfPath", qopenhdConfPath)
        imageWriter.setSetting("premiumCertificatePath", premiumCertificatePath)

    }

    function isRpiCsiCamera(cameraSelection) {
        if (!cameraSelection || !settingsMap.camera || !settingsMap.camera.sbcGroups)
            return false

        for (var groupIdx = 0; groupIdx < settingsMap.camera.sbcGroups.length; groupIdx++) {
            var group = settingsMap.camera.sbcGroups[groupIdx]
            if (!group || !group.sbc || group.sbc.indexOf("rpi") === -1 || !group.vendors)
                continue
            for (var vendorIdx = 0; vendorIdx < group.vendors.length; vendorIdx++) {
                var options = group.vendors[vendorIdx].options || []
                for (var optionIdx = 0; optionIdx < options.length; optionIdx++) {
                    if (options[optionIdx].id === cameraSelection) {
                        var cameraType = parseInt(options[optionIdx].valueWritten)
                        return cameraType >= 20 && cameraType <= 69
                    }
                }
            }
        }
        return false
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
            console.log("[OptionsPopup] settings map loaded with keys:", Object.keys(settingsMap))
        } catch (e) {
            console.log("Failed to load OpenHD settings map: " + e)
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
}
