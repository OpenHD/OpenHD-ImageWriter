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
    property string mode
    property string hotSpot
    property string beep
    property string eject
    property bool rock3
    property bool rock5
    property bool rpi
    property bool useSettings:true
    property string qopenhdConfPath: ""

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
        spacing: 20
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
                            model: settingsMap.bootType && settingsMap.bootType.options ? settingsMap.bootType.options.filter(function(option) { return option.id && option.id.length > 0 }) : []
                            delegate: ImCheckBox {
                                property var option: modelData
                                text: qsTr("Set SBC to %1").arg(option ? option.id : "")
                                checked: bootType === (option ? option.id : "")
                                onClicked: {
                                    if (option) {
                                        bootType = option.id
                                    }
                                }
                            }
                        }
                    }
                }
                GroupBox {
                    title: qsTr("Camera Settings")
                    id: cameraSettings
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: -10
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
                                    spacing: -10

                                    property var vendorList: groupData && groupData.vendors ? groupData.vendors : []
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
                                                }
                                            }
                                        }
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
                        visible: settingsMap.mode && settingsMap.mode.options && settingsMap.mode.options.length > 0
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
                            visible: settingsMap.hotSpot && settingsMap.hotSpot.options && settingsMap.hotSpot.options.length > 0
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
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter | Qt.AlignBottom
            Layout.bottomMargin: 10
            spacing: 20

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
            qopenhdConfPath = qopenhdConfDialog.fileUrl.toLocalFile()
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
        mode = imageWriter.getValue("mode")
        hotSpot = imageWriter.getValue("hotSpot")
        beep = imageWriter.getBoolSetting("beep")
        eject = imageWriter.getBoolSetting("eject")
        qopenhdConfPath = imageWriter.getValue("qopenhdConfPath")

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

        //get SBC
        imageWriter.setSetting("fileName", fileName)
        console.log("[OptionsPopup] src file:", fileName)
        if (fileName.includes("pi")) {
            imageWriter.setSetting("sbc", "rpi");
            sbc = "rpi"
            rpi=true;
            rock5=false;
            rock3=false;
        }
        else if (fileName.includes("rock5a")) {
            imageWriter.setSetting("sbc", "rock-5a");
            sbc = "rock-5a"
            rpi=false;
            rock5=true;
            rock3=false;
        }
        else if (fileName.includes("rock5b")) {
            imageWriter.setSetting("sbc", "rock-5b");
            sbc = "rock-5b"
            rpi=false;
            rock5=true;
            rock3=false;
        }
        else if (fileName.includes("zero3w")) {
            imageWriter.setSetting("sbc", "zero3w");
            sbc = "zero3w"
            rpi=false;
            rock5=false;
            rock3=true;
        }
        else{
           imageWriter.setSetting("sbc", "unknown");
           sbc = "unknown"
           rpi=false;
           rock5=false;
           rock3=false;
        }

        console.log("[OptionsPopup] detected SBC:", sbc)
        console.log("[OptionsPopup] saved camera:", camera)

        initialized = true
    }

    function openPopup() {
        if (!initialized) {
            initialize()
        }

        open()
        popupbody.forceActiveFocus()
    }

    function applySettings()
    {

        imageWriter.setSetting("bootType", bootType)
        imageWriter.setSetting("camera", camera)
        imageWriter.setSetting("mode", mode)
        imageWriter.setSetting("hotSpot" , hotSpot)
        imageWriter.setSetting("beep", beep)
        imageWriter.setSetting("eject", eject)
        imageWriter.setSetting("useSettings", useSettings)
        imageWriter.setSetting("qopenhdConfPath", qopenhdConfPath)

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
}
