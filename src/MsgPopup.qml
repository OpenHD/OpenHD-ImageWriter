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
    property string noButtonText: qsTr("NO")
    property bool configureButton: false
    property bool closeButton: false
    property bool rescanButton: false
    property bool showCloseIcon: true
    property string detailsSnapshot: ""
    signal yes()
    signal no()
    signal configure()
    signal rescan()

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
        visible: msgpopup.showCloseIcon
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
                onClicked: detailsPopup.open()
                Material.foreground: activeFocus ? "#d1dcfb" : "#ffffff"
                Material.background: "#2C3E50"
            }

            ImButton {
                text: msgpopup.noButtonText
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
                text: qsTr("RESCAN")
                onClicked: {
                    msgpopup.close()
                    msgpopup.rescan()
                }
                visible: msgpopup.rescanButton
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

    Popup {
        id: detailsPopup
        parent: msgpopup.parent
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(620, parent.width - 32)
        height: Math.min(500, parent.height - 32)
        padding: 0
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 10
            color: "#102633"
            border.color: "#31515f"
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Write details")
                    color: "#f3f7fa"
                    font.family: roboto.name
                    font.pixelSize: 18
                    font.bold: true
                }

                ToolButton {
                    text: "×"
                    onClicked: detailsPopup.close()
                    contentItem: Text {
                        text: parent.text
                        color: "#dce8ef"
                        font.pixelSize: 22
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: "transparent" }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#294754"
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    width: parent.width
                    text: msgpopup.detailsSnapshot
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: "#b8c7d0"
                    font.family: roboto.name
                    font.pixelSize: 13
                    background: Rectangle {
                        radius: 7
                        color: "#0d202b"
                        border.color: "#294754"
                    }
                }
            }

            ModernActionButton {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Close")
                primary: true
                onClicked: detailsPopup.close()
            }
        }
    }

    function appendDetail(lines, label, value) {
        var textValue = value === undefined || value === null ? "" : String(value)
        if (textValue.length > 0)
            lines.push(label + ": " + textValue)
    }

    function captureDetails() {
        var lines = []
        appendDetail(lines, qsTr("Image"), imageWriter.srcFileName())
        appendDetail(lines, qsTr("Source"), imageWriter.src())
        appendDetail(lines, qsTr("Target"), imageWriter.dst())
        appendDetail(lines, qsTr("Device role"), imageWriter.getValue("bootType"))
        appendDetail(lines, qsTr("SBC"), imageWriter.getValue("sbc"))
        appendDetail(lines, qsTr("Primary camera"), imageWriter.getValue("camera"))
        appendDetail(lines, qsTr("Primary resolution"), imageWriter.getValue("cameraResolution"))
        appendDetail(lines, qsTr("Secondary camera"), imageWriter.getValue("camera2"))
        appendDetail(lines, qsTr("Secondary resolution"), imageWriter.getValue("camera2Resolution"))
        appendDetail(lines, qsTr("Mode"), imageWriter.getValue("mode"))
        detailsSnapshot = lines.length > 0
                ? lines.join("\n")
                : qsTr("No additional write details are available.")
    }

    function openPopup() {
        if (detailsButton)
            captureDetails()
        open()
        // trigger screen reader to speak out message
        msgpopupbody.forceActiveFocus()
    }
}

