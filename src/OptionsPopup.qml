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
    property bool rock3
    property bool rock5
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
                ColumnLayout {
                    id: dynamicSettingsColumn
                    spacing: 10
                }

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

    function loadXmlSettings(fileName) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("configs/" + fileName));
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    console.log("XML loaded successfully:", fileName);

                    var xmlText = xhr.responseText;

                    // Step 1: apply <Property> entries
                    var regex = /<Property\s+key="([^"]+)"\s+value="([^"]+)"\s*\/>/g;
                    var match;
                    while ((match = regex.exec(xmlText)) !== null) {
                        var key = match[1];
                        var value = match[2];

                        imageWriter.setSetting(key, value);

                        if (popup.hasOwnProperty(key)) {
                            popup[key] = (value === "true") ? true :
                                                              (value === "false") ? false :
                                                                                    value;
                        }

                        console.log("Applied XML property:", key, "=", value);
                    }

                    // Step 2: parse <Settings><Group>...</Group></Settings>
                    var settingsMatch = xmlText.match(/<Settings>([\s\S]*?)<\/Settings>/);
                    if (settingsMatch) {
                        var settingsXml = settingsMatch[1];

                        var groupRegex = /<Group[^>]*title="([^"]+)"[^>]*visibleIf="([^"]+)"[^>]*>([\s\S]*?)<\/Group>/g;
                        var groupMatch;

                        while ((groupMatch = groupRegex.exec(settingsXml)) !== null) {
                            var groupTitle = groupMatch[1];
                            var visibleIf = groupMatch[2];
                            var groupContent = groupMatch[3];

                            console.log("Creating Group:", groupTitle, "Visible if:", visibleIf);
                            var groupObject = createComboBoxGroup(groupTitle, visibleIf, groupContent);
                            if (groupObject) {
                                groupObject.parent = dynamicSettingsColumn;
                            }
                        }
                    }
                } else {
                    console.log("Failed to load XML config:", fileName);
                }
            }
        }
        xhr.send();
    }

    function createComboBoxGroup(title, visibleIfExpr, innerXml) {
        var comboMatch = innerXml.match(/<ComboBox[^>]*key="([^"]+)"[^>]*>([\s\S]*?)<\/ComboBox>/);
        if (!comboMatch)
            return null;

        var key = comboMatch[1];
        var optionsXml = comboMatch[2];

        var options = [];

        // Detect if <Brand> tags are used
        var hasBrands = optionsXml.includes("<Brand");

        if (hasBrands) {
            // Parse <Brand name="..."> with nested <Option text="..."/>
            var brandRegex = /<Brand\s+name="([^"]+)"[^>]*>([\s\S]*?)<\/Brand>/g;
            var brandMatch;
            while ((brandMatch = brandRegex.exec(optionsXml)) !== null) {
                var brandName = brandMatch[1];
                var brandOptionsXml = brandMatch[2];

                var brandOptions = [];
                var optionRegex = /<Option[^>]*text="([^"]+)"[^>]*\/>/g;
                var optionMatch;

                while ((optionMatch = optionRegex.exec(brandOptionsXml)) !== null) {
                    brandOptions.push(optionMatch[1]);
                }

                options.push({
                                 brand: brandName,
                                 models: brandOptions
                             });
            }
        } else {
            // Fallback: flat <Option text="..."/>
            var optionRegex = /<Option[^>]*text="([^"]+)"[^>]*\/>/g;
            var optionMatch;

            while ((optionMatch = optionRegex.exec(optionsXml)) !== null) {
                options.push(optionMatch[1]);
            }
        }

        var component = Qt.createComponent("qmlcomponents/ComboBoxGroup.qml");
        if (component.status !== Component.Ready) {
            console.log("Component error:", component.errorString());
            return null;
        }

        return component.createObject(dynamicSettingsColumn, {
                                          groupTitle: title,
                                          visibleIf: visibleIfExpr,
                                          settingKey: key,
                                          optionsList: options,
                                          popup: popup
                                      });
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

        // Get SBC by matching known XML config names
        imageWriter.setSetting("fileName", fileName)
        console.log("File name is:", fileName)

        function findSbcXmlConfig(fileName) {
            const candidates = ["pi-bullseye", "rock-5a", "rock-5b", "zero3w"]
            for (let i = 0; i < candidates.length; i++) {
                if (fileName.includes(candidates[i])) {
                    return candidates[i] + ".xml"
                }
            }
            return "unknown.xml"
        }

        let configXml = findSbcXmlConfig(fileName)
        console.log("Matched SBC config:", configXml)

        // Load *after bindings have settled*
        Qt.callLater(function() {
            loadXmlSettings(configXml)
        })

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
