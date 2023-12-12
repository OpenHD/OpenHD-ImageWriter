/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2021 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2
import Qt.labs.settings 1.0
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

    // refactored settings
    property string bootType
    property string fileName
    property string sbc
    property string camera
    property string bindPhrase
    property bool bindPhrase_used
    property string mode
    property string hotSpot
    property string beep
    property string eject
    property bool rock
    property bool rpi
    property bool useSettings:true




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

                        ImCheckBox {
                            id: setAir
                            text: qsTr("Set SBC to AIR")
                            onCheckedChanged: {
                                if (checked) {
                                    setGround.checked = false
                                    bootType="Air";
                                }
                            }
                        }
                        ImCheckBox {
                            id: setGround
                            text: qsTr("Set SBC to GROUND")
                            onCheckedChanged: {
                                if (checked) {
                                    setAir.checked = false
                                    bootType = "Ground";
                                }
                            }
                        }
                    }
                }
                GroupBox {
                    title: qsTr("Camera Settings")
                    id: cameraSettingsRock5
                    Layout.fillWidth: true
                    visible: rock && (bootType === "Air")


                    ColumnLayout {
                        spacing: -10
                        // Add a ComboBox to select between cameras
                        ComboBox {
                            id: cameraSelectorRock
                            textRole: "displayText"
                            model: ListModel {
                                ListElement { displayText: "NONE" }
                                ListElement { displayText: "IMX415" }
                                ListElement { displayText: "IMX462" }
                                ListElement { displayText: "HDMI" }
                            }
                            onCurrentIndexChanged: {
                                var selectedCamera = model.get(currentIndex).displayText;
                                if (selectedCamera !== "NONE") {
                                    camera = selectedCamera;
                                }
                            }
                        }
                    }
                }
                GroupBox {
                    title: qsTr("Camera Settings")
                    id: cameraSettingsRpi
                    Layout.fillWidth: true
                    visible:  rpi && (bootType === "Air")
                    ColumnLayout {
                        // Add a ComboBox to select between cameras
                        ComboBox {
                            id: cameraVendorSelectorRpi
                            textRole: "displayText"
                            model: ListModel {
                                ListElement { displayText: "Original" }
                                ListElement { displayText: "Arducam" }
                                ListElement { displayText: "Veye" }
                            }
                            Layout.minimumWidth: 200
                            Layout.maximumHeight: 40
                            onCurrentIndexChanged: {
                                var selectedCameraVendor = model.get(currentIndex).displayText;
                                if (selectedCameraVendor !== "Original" && selectedCameraVendor !== "Veye") {
                                    cameraSelectorArducam.visible=true
                                    cameraSelectorVeye.visible=false
                                }
                                else if (selectedCameraVendor !== "Original" && selectedCameraVendor !== "Arducam") {
                                    cameraSelectorVeye.visible=true
                                    cameraSelectorArducam.visible=false
                                }

                            }
                        }
                        ComboBox {

                            id: cameraSelectorArducam
                            visible:false
                            textRole: "displayText"
                            model: ListModel {
                                ListElement { displayText: "None" }
                                ListElement { displayText: "SkyMaster HDR 708" }
                                ListElement { displayText: "IMX462 Mini" }
                                ListElement { displayText: "SkyVision Pro 519" }
                                ListElement { displayText: "IMX462" }
                                ListElement { displayText: "IMX477" }
                                ListElement { displayText: "IMX519" }
                                ListElement { displayText: "IMX327" }
                                ListElement { displayText: "IMX290" }
                                ListElement { displayText: "CUSTOM" }
                            }
                            Layout.minimumWidth: 200
                            Layout.maximumHeight: 40
                            onCurrentIndexChanged: {
                                var selectedCamera = model.get(currentIndex).displayText;
                                if (selectedCamera !== "None") {
                                    // Check if it's one of the specified values
                                    if (["SkyMaster HDR 708", "IMX462 Mini", "SkyVision Pro 519"].indexOf(selectedCamera) === -1) {
                                        camera = selectedCamera;
                                    } else {
                                        // Handle the specified values differently
                                        if (selectedCamera === "SkyMaster HDR 708") {
                                            camera = "IMX708";
                                        } else if (selectedCamera === "IMX462 Mini") {
                                            camera = "ARDUCAM";
                                        } else if (selectedCamera === "SkyVision Pro 519") {
                                            camera = "IMX519";
                                        }
                                    }
                                }
                            }
                        }
                        ComboBox {

                            id: cameraSelectorVeye
                            visible:false
                            textRole: "displayText"
                            model: ListModel {
                                ListElement { displayText: "None" }
                                ListElement { displayText: "CAM2M" }
                                ListElement { displayText: "CSIMX307" }
                                ListElement { displayText: "CSSC137" }
                                ListElement { displayText: "MVCAM" }
                            }
                            Layout.minimumWidth: 200
                            Layout.maximumHeight: 40
                            onCurrentIndexChanged: {
                                var selectedCamera = model.get(currentIndex).displayText;
                                if (selectedCamera !== "None") {
                                    console.debug(selectedCamera)
                                }
                            }
                        }

                    }
                }
                GroupBox {
                    title: qsTr("Bind Settings")
                    Layout.fillWidth: true
                    visible: true

                    ColumnLayout {
                        spacing: 0

                        Text {
                            text: qsTr("   Must match on Air and Ground!")
                            font.pixelSize: 12
                            color: "gray"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        ImCheckBox {
                            id: bndKey
                            text: qsTr("Set binding phrase")
                            checkable: true
                            onCheckedChanged: {
                                if (!checked) {
                                    bindPhrase=""
                                    bndPhrase.visible=false;
                                }
                                bndPhrase.visible=true;
                            }
                        }
                        TextField {
                            id: bndPhrase
                            visible: bindPhrase_used
                            maximumLength:10
                            width:10
                            color: bndPhrase.text.length >= 4 ? "green" : "red"
                            text: bindPhrase
                            selectByMouse: true
                            placeholderTextColor: "blue"
                            placeholderText: "openhd"
                            onTextChanged: {
                                bindPhrase = bndPhrase.text;
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
                        visible: true
                        text: qsTr("Debug Mode")
                        onCheckedChanged: {
                            if (checked) {
                                mode = "debug";
                            }
                        }
                    }

                        ImCheckBox {
                            id: setWifiHotspot
                            visible: false
                            text: qsTr("WifiHotspot")
                            onCheckedChanged: {
                                if (checked) {
                                    hotSpot = "wifi";
                                }
                            }
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

    function initialize() {
        var settings = imageWriter.getSavedCustomizationSettings()

        // initialise settings
        bootType = imageWriter.getValue("bootType")
        fileName = imageWriter.srcFileName();
        sbc = imageWriter.getValue("sbc")
        camera= imageWriter.getValue("camera")
        bindPhrase = imageWriter.getValue("bindPhrase")
        mode = imageWriter.getValue("mode")
        hotSpot = imageWriter.getValue("hotSpot")
        beep = imageWriter.getBoolSetting("beep")
        eject = imageWriter.getBoolSetting("eject")

        // set session settings
        if (bootType==="Air") {
            setAir.checked=true
            setGround.checked=false
        }
        else if (bootType==="Ground") {
            setAir.checked=false
            setGround.checked=true
        }
        if (bindPhrase) {
            bndKey.checked=true
        }
        else{
            bndKey.checked=false
        }
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
        console.log(fileName)
        if (fileName.includes("pi")) {
            imageWriter.setSetting("sbc", "rpi");
            rpi=true;
            rock=false;
        }
        else if (fileName.includes("rock5a")) {
            imageWriter.setSetting("sbc", "rock-5a");
            rpi=false;
            rock=true;
        }
        else if (fileName.includes("rock5b")) {
            imageWriter.setSetting("sbc", "rock-5b");
            rpi=false;
            rock=true;
        }
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
        imageWriter.setSetting("bindPhrase" , bindPhrase)
        imageWriter.setSetting("mode", mode)
        imageWriter.setSetting("hotSpot" , hotSpot)
        imageWriter.setSetting("beep", beep)
        imageWriter.setSetting("eject", eject)
        imageWriter.setSetting("useSettings", useSettings)

    }
}
