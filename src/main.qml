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

    property var featureWindow: null
    property string statusMessage: ""

    function forwardIfAvailable(name, args) {
        if (featureWindow && featureWindow[name]) {
            featureWindow[name].apply(featureWindow, args)
        }
    }

    function loadFeature(source) {
        if (featureWindow) {
            featureWindow.destroy()
            featureWindow = null
        }

        var component = Qt.createComponent(Qt.resolvedUrl(source))

        if (component.status === Component.Ready) {
            featureWindow = component.createObject(null, { mainWindow: window })

            if (!featureWindow) {
                statusMessage = qsTr("Could not open %1").arg(source)
                console.error(component.errorString())
                return
            }

            statusMessage = ""
            window.visible = false

            featureWindow.destroyed.connect(function() {
                featureWindow = null
                window.visible = true
            })
            return
        }

        if (component.status === Component.Error) {
            statusMessage = qsTr("Could not open %1").arg(source)
            console.error(component.errorString())
        }
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

    ColumnLayout {
        id: bg
        spacing: 0
        anchors.fill: parent

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: window.height / 2
            color: "transparent"

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
                        onClicked: loadFeature("flash.qml")
                    }

                    ImButton {
                        text: qsTr("UPDATE")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 150
                        onClicked: loadFeature("update.qml")
                    }

                    ImButton {
                        text: qsTr("CONFIGURE")
                        Layout.fillWidth: true
                        Layout.preferredWidth: 150
                        onClicked: loadFeature("configure.qml")
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
