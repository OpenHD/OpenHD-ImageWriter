/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2021 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2
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
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    property bool initialized: false
    property bool hasSavedSettings: false
    property string config
    property string cmdline
    property string openHDAir
    property string openHDGround
    property string cloudinit
    property string cloudinitrun
    property string cloudinitwrite
    property string cloudinitnetwork

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

    Text {
        id: msgx
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
            onClicked: {
                popup.close()
            }
        }
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
                  title: qsTr("Save")

                                  label: RowLayout {
                                      Label {
                                          text: parent.parent.title
                                      }
                                      ComboBox {
                                          id: comboSaveSettings
                                          model: {
                                              [qsTr("for this session only"),
                                               qsTr("to always use")]
                                          }
                                          Layout.minimumWidth: 250
                                          Layout.maximumHeight: 40
                                          enabled: !imageWriter.isEmbeddedMode()
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
                                  bootAsAir();
                              }
                          }
                      }
                      ImCheckBox {
                          id: setGround
                          text: qsTr("Set SBC to GROUND")
                          onCheckedChanged: {
                              if (checked) {
                                  setAir.checked = false
                                  bootAsGround();

                              }
                          }
                      }
                  }
              }
              GroupBox {
                  title: qsTr("Bind Settings")
                  Layout.fillWidth: true

                  ColumnLayout {
                      spacing: -10

                      ImCheckBox {
                          id: bndKey
                          text: qsTr("Set custom bind key")
                          onCheckedChanged: {
                              if (checked) {
                                  autoBndKey.checked = false
                              }
                          }
                      }
                      ImCheckBox {
                          id: autoBndKey
                          text: qsTr("Autogenerate bind key")
                          onCheckedChanged: {
                              if (checked) {
                                  bndKey.checked = false
                              }
                          }
                      }
                      TextField {
                          id: custBndKey
                          Layout.minimumWidth: 200
                      }
                  }
              }

            GroupBox {
                title: qsTr("Imager settings")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: -10

                    ImCheckBox {
                        id: chkBeep
                        text: qsTr("Play sound when finished")
                    }
                    ImCheckBox {
                        id: chkEject
                        text: qsTr("Eject media when finished")
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
                    saveSettings()
                    popup.close()
                }
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }

            Text { text: " " }
        }
    }

    function initialize() {
        chkBeep.checked = imageWriter.getBoolSetting("beep")
        chkEject.checked = imageWriter.getBoolSetting("eject")
        var settings = imageWriter.getSavedCustomizationSettings()

        if (Object.keys(settings).length) {
            comboSaveSettings.currentIndex = 1
            hasSavedSettings = true
        }       
        var tz;
        if (imageWriter.isEmbeddedMode()) {
            /* For some reason there is no password mask character set by default on Embedded edition */
            var bulletCharacter = String.fromCharCode(0x2022);
            fieldUserPassword.passwordCharacter = bulletCharacter;
            fieldWifiPassword.passwordCharacter = bulletCharacter;
        }

        initialized = true
    }

    function openPopup() {
        if (!initialized) {
            initialize()
        }

        open()
        popupbody.forceActiveFocus()
    }

    function addCmdline(s) {
        cmdline += " "+s
    }
    function addConfig(s) {
        config += s+""
    }
    function bootAsGround(s) {
        openHDGround += s+""
    }
    function bootAsAir(s) {
        openHDAir += s+""
    }
    function escapeshellarg(arg) {
        return "'"+arg.replace(/'/g, "\\'")+"'"
    }
    function addCloudInit(s) {
        cloudinit += s+"\n"
    }
    function addCloudInitWriteFile(name, content, perms) {
        cloudinitwrite += "- encoding: b64\n"
        cloudinitwrite += "  content: "+Qt.btoa(content)+"\n"
        cloudinitwrite += "  owner: root:root\n"
        cloudinitwrite += "  path: "+name+"\n"
        cloudinitwrite += "  permissions: '"+perms+"'\n"
    }
    function addCloudInitRun(cmd) {
        cloudinitrun += "- "+cmd+"\n"
    }

    function applySettings()
    {
        cmdline = ""
        config = ""
        openHDGround = ""
        openHDAir = ""
        cloudinit = ""
        cloudinitrun = ""
        cloudinitwrite = ""
        cloudinitnetwork = ""

        if (setAir.checked) {
            bootAsAir("applied")
        }
        if (setGround.checked) {
            bootAsGround("applied")
        }

        if (openHDGround.length) {
            openHDGround = ""+openHDGround
         }

        if (openHDAir.length) {
            openHDAir = ""+openHDAir
         }

        if (cloudinitwrite !== "") {
            addCloudInit("write_files:\n"+cloudinitwrite+"\n")
        }

        if (cloudinitrun !== "") {
            addCloudInit("runcmd:\n"+cloudinitrun+"\n")
        }

        imageWriter.setImageCustomization(config, cmdline, openHDAir, openHDGround, cloudinit, cloudinitnetwork)
    }

    function saveSettings()
    {
        if (comboSaveSettings.currentIndex == 1) {
            hasSavedSettings = true
            var settings = { };
            if (chkHostname.checked && fieldHostname.length) {
                settings.hostname = fieldHostname.text
            }

            imageWriter.setSavedCustomizationSettings(settings)

        } else if (hasSavedSettings) {
            imageWriter.clearSavedCustomizationSettings()
            hasSavedSettings = false
        }

        imageWriter.setSetting("beep", chkBeep.checked)
        imageWriter.setSetting("eject", chkEject.checked)
    }
}
