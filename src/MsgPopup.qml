/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2
import "qmlcomponents"

Popup {
    id: msgpopup
    x: (parent.width-width)/2
    y: (parent.height-height)/2
    width: Math.min(560, parent.width-32)
    height: Math.min(parent.height-32, msgpopupbody.implicitHeight+185)
    padding: 0
    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    background: Rectangle {
        radius: 10
        color: "#102633"
        border.color: "#31515f"
    }

    property alias title: msgpopupheader.text
    property alias text: msgpopupbody.text
    property bool continueButton: true
    property bool detailsButton: false
    property bool quitButton: false
    property bool yesButton: false
    property bool noButton: false
    property bool configureButton: false
    property bool closeButton: false
    signal yes()
    signal no()
    signal configure()

    // background of title
    Rectangle {
        color: "#102633"
        anchors.right: parent.right
        anchors.top: parent.top
        height: 35
        width: parent.width
    }
    // line under title
    Rectangle {
        color: "#294754"
        width: parent.width
        y: 35
        implicitHeight: 1
    }

    Text {
        id: msgx
        text: "X"
        color: "#dce8ef"
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
                msgpopup.close()
            }
        }
    }

    ColumnLayout {
        spacing: 20
        anchors.fill: parent

        Text {
            id: msgpopupheader
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
            Layout.topMargin: 10
            font.family: roboto.name
            font.bold: true
            color: "#f3f7fa"
            font.pixelSize: 17
        }

        Text {
            id: msgpopupbody
            font.pointSize: 12
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            font.family: roboto.name
            color: "#b8c7d0"
            Layout.maximumWidth: msgpopup.width-50
            Layout.fillHeight: true
            Layout.leftMargin: 25
            Layout.topMargin: 25
            Accessible.name: text.replace(/<\/?[^>]+(>|$)/g, "")
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter | Qt.AlignBottom
            Layout.bottomMargin: 14
            spacing: 20


            ImButton {
                visible: msgpopup.detailsButton
                text: qsTr("Details")
                onClicked:{
                   onClicked: {
                   detailsPopup.visible = !detailsPopup.visible;
                   }
                }
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
                }

            ImButton {
                text: qsTr("NO")
                onClicked: {
                    msgpopup.close()
                    msgpopup.no()
                }
                visible: msgpopup.noButton
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }

            ImButton {
                text: qsTr("YES")
                onClicked: {
                    msgpopup.close()
                    msgpopup.yes()
                }
                visible: msgpopup.yesButton
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }

            ImButton {
                text: qsTr("CONTINUE")
                onClicked: {
                    msgpopup.close()
                }
                visible: msgpopup.continueButton
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }
            ImButton {
                text: qsTr("CONFIGURE")
                onClicked: {
                    msgpopup.close()
                    msgpopup.configure()
                }
                visible: msgpopup.configureButton
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }
            ImButton {
                text: qsTr("CLOSE")
                onClicked: {
                    Qt.quit()
                }
                visible: msgpopup.closeButton
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }
            ImButton {
                text: qsTr("QUIT")
                onClicked: {
                    Qt.quit()
                }
                font.family: roboto.name
                visible: msgpopup.quitButton
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }

            Text { text: " " }
        }
    }

    function openPopup() {
        open()
        // trigger screen reader to speak out message
        msgpopupbody.forceActiveFocus()
    }
}

