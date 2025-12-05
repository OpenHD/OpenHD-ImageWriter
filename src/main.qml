/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Window 2.2
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2
import "qmlcomponents"

ApplicationWindow {
    id: window
    visible: true
    color: "#34495E"

    width: imageWriter.isEmbeddedMode() ? -1 : 680
    height: imageWriter.isEmbeddedMode() ? -1 : 420
    minimumWidth: imageWriter.isEmbeddedMode() ? -1 : 680
    minimumHeight: imageWriter.isEmbeddedMode() ? -1 : 420

    title: qsTr("OpenHD ImageWriter v%1").arg(imageWriter.constantVersion())

    FontLoader { id: roboto; source: "fonts/Roboto-Regular.ttf" }
    FontLoader { id: robotoBold; source: "fonts/Roboto-Bold.ttf" }

    property string currentView: "home"
    property string statusMessage: ""

    function currentFeature() {
        if (currentView === "flash") {
            return flashLoader.item
        }
        if (currentView === "update") {
            return updateLoader.item
        }
        if (currentView === "configure") {
            return configureLoader.item
        }
        return null
    }

    function forwardIfAvailable(name, args) {
        var target = currentFeature()
        if (target && target[name]) {
            target[name].apply(target, args)
        }
    }

    function openFeature(name) {
        statusMessage = ""
        currentView = name
    }

    function showHome() {
        currentView = "home"
    }

    function onDownloadProgress(now, total) {
        forwardIfAvailable("onDownloadProgress", [now, total])
    }

    function onWriteProgress(now, total) {
        forwardIfAvailable("onWriteProgress", [now, total])
    }

    function onVerifyProgress(now, total) {
        forwardIfAvailable("onVerifyProgress", [now, total])
    }

    function onPreparationStatusUpdate(status) {
        forwardIfAvailable("onPreparationStatusUpdate", [status])
    }

    function onError(error) {
        forwardIfAvailable("onError", [error])
    }

    function onSuccess() {
        forwardIfAvailable("onSuccess", [])
    }

    function onUpdateUploadProgress(progress) {
        forwardIfAvailable("onUpdateUploadProgress", [progress])
    }

    function onUpdateUploadStatus(status) {
        forwardIfAvailable("onUpdateUploadStatus", [status])
    }

    function onUpdateUploadError(error) {
        forwardIfAvailable("onUpdateUploadError", [error])
    }

    function onUpdateUploadSuccess() {
        forwardIfAvailable("onUpdateUploadSuccess", [])
    }

    function onFileSelected(file) {
        forwardIfAvailable("onFileSelected", [file])
    }

    function onCancelled() {
        forwardIfAvailable("onCancelled", [])
    }

    function onFinalizing() {
        forwardIfAvailable("onFinalizing", [])
    }

    function fetchOSlist() {
        forwardIfAvailable("fetchOSlist", [])
    }

    Loader {
        id: flashLoader
        anchors.fill: parent
        source: "flash.qml"
        active: true
        visible: currentView === "flash"
        enabled: visible
        onLoaded: item.mainWindow = window
    }

    Loader {
        id: updateLoader
        anchors.fill: parent
        source: "update.qml"
        active: true
        visible: currentView === "update"
        enabled: visible
        onLoaded: item.mainWindow = window
    }

    Loader {
        id: configureLoader
        anchors.fill: parent
        source: "configure.qml"
        active: true
        visible: currentView === "configure"
        enabled: visible
        onLoaded: item.mainWindow = window
    }

    Item {
        id: homeView
        anchors.fill: parent
        visible: currentView === "home"

        ColumnLayout {
            id: bg
            spacing: 0
            anchors.fill: parent

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.height / 2
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

                    // Scale relative to the top half area
                    width: parent.width * 0.7
                    height: parent.height
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.height / 2
                color: "#2C3E50"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 32
                    spacing: 24

                    RowLayout {
                        spacing: 16
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true

                        ImButton {
                            text: qsTr("FLASH")
                            Layout.fillWidth: true
                            Layout.preferredWidth: 150
                            onClicked: openFeature("flash")
                        }

                        ImButton {
                            text: qsTr("UPDATE")
                            Layout.fillWidth: true
                            Layout.preferredWidth: 150
                            onClicked: openFeature("update")
                        }

                        ImButton {
                            text: qsTr("CONFIGURE")
                            Layout.fillWidth: true
                            Layout.preferredWidth: 150
                            onClicked: openFeature("configure")
                        }
                    }

                    Label {
                        text: statusMessage
                        color: "#ffdf6d"
                        visible: statusMessage !== ""
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
