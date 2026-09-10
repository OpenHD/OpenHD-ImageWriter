/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Window 2.2
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2
import "qmlcomponents"

ApplicationWindow {
    id: window
    visible: true
    color: "#071721"

    width: imageWriter.isEmbeddedMode() ? -1 : 1100
    height: imageWriter.isEmbeddedMode() ? -1 : 700
    minimumWidth: imageWriter.isEmbeddedMode() ? -1 : 720
    minimumHeight: imageWriter.isEmbeddedMode() ? -1 : 500

    title: qsTr("OpenHD ImageWriter v%1").arg(imageWriter.constantVersion())
    Material.theme: Material.Dark
    Material.accent: "#168df3"
    Material.primary: "#0b1c27"
    font.family: roboto.name

    FontLoader { id: roboto; source: "fonts/Roboto-Regular.ttf" }
    FontLoader { id: robotoBold; source: "fonts/Roboto-Bold.ttf" }

    property string currentView: "home"
    property string statusMessage: ""
    property string transientMessage: ""
    property bool compactNavigation: width < 900
    property int navigationWidth: compactNavigation ? 68 : 216

    Component.onCompleted: {
        if (!imageWriter.hasOpenHdSettingsCard()) {
            openFeature("flash")
        }
    }

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
        if (name === currentView) {
            var current = currentFeature()
            if (current && current.returnToOverview)
                current.returnToOverview()
            return
        }

        var activeFeature = currentFeature()
        if (activeFeature && activeFeature.operationInProgress) {
            transientMessage = qsTr("Finish or cancel the current operation before leaving this page.")
            transientMessageTimer.restart()
            return
        }

        if (activeFeature && activeFeature.returnToOverview)
            activeFeature.returnToOverview()

        statusMessage = ""
        transientMessage = ""
        currentView = name
    }

    function showHome() {
        openFeature("home")
    }

    function openLanguagePopup() {
        languagePopup.open()
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

    Rectangle {
        anchors.fill: parent
        color: "#071721"

        Rectangle {
            anchors.fill: parent
            color: "#0c2230"
            opacity: 0.32
        }
    }

    ModernSidebar {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: window.navigationWidth
        currentView: window.currentView
        onNavigate: window.openFeature(view)
        onLanguageRequested: window.openLanguagePopup()

        Behavior on width {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: contentSurface
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: "#0c202c"
        clip: true

        Rectangle {
            anchors.fill: parent
            color: "#071721"
            opacity: 0.22
        }

        ModernHome {
            anchors.fill: parent
            visible: currentView === "home"
            enabled: visible
            statusMessage: window.statusMessage
            onFeatureRequested: window.openFeature(view)
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

        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 18
            width: Math.min(noticeText.implicitWidth + 36, parent.width - 36)
            height: noticeText.implicitHeight + 22
            radius: 7
            color: "#3b3010"
            border.color: "#b58c16"
            visible: transientMessage !== ""
            z: 100

            Text {
                id: noticeText
                anchors.fill: parent
                anchors.margins: 11
                text: transientMessage
                color: "#ffe49a"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
            }
        }
    }

    Timer {
        id: transientMessageTimer
        interval: 4000
        onTriggered: transientMessage = ""
    }

    Popup {
        id: languagePopup
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        width: Math.min(420, window.width - 48)
        height: 230
        padding: 0
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: {
            var currentLang = imageWriter.getCurrentLanguage()
            languageSelector.currentIndex = languageSelector.find(currentLang)
        }

        background: Rectangle {
            radius: 10
            color: "#102633"
            border.color: "#31505f"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 22
                Layout.rightMargin: 12
                Layout.topMargin: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: qsTr("Language")
                        color: "#f4f8fb"
                        font.family: robotoBold.name
                        font.bold: true
                        font.pixelSize: 20
                    }

                    Text {
                        text: qsTr("Choose the language used by ImageWriter.")
                        color: "#9fb3c0"
                        font.pixelSize: 12
                    }
                }

                ToolButton {
                    text: "×"
                    font.pixelSize: 22
                    onClicked: languagePopup.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 22
                Layout.rightMargin: 22
                Layout.preferredHeight: 1
                color: "#294654"
            }

            ComboBox {
                id: languageSelector
                Layout.fillWidth: true
                Layout.leftMargin: 22
                Layout.rightMargin: 22
                currentIndex: -1
                model: imageWriter.getTranslations()
                onActivated: {
                    imageWriter.changeLanguage(editText)
                    imageWriter.setSetting("language", editText)
                }
            }

            Item { Layout.fillHeight: true }

            Button {
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 22
                Layout.bottomMargin: 18
                text: qsTr("Done")
                onClicked: languagePopup.close()
            }
        }
    }
}
