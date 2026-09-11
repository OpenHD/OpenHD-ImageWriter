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

    property bool embeddedMode: imageWriter.isEmbeddedMode()

    width: embeddedMode ? -1 : 950
    height: embeddedMode ? -1 : 640

    minimumWidth: embeddedMode ? -1 : 640
    minimumHeight: embeddedMode ? -1 : 440

    /*
     * We keep the title for the taskbar / operating system,
     * even though the visible title bar is now drawn in QML.
     */
    title: qsTr("OpenHD ImageWriter v%1").arg(imageWriter.constantVersion())

    /*
     * Custom window frame on desktop.
     *
     * Embedded mode keeps the normal Window flag so we don't interfere
     * with the existing embedded/fullscreen behaviour.
     */
    flags: embeddedMode
           ? Qt.Window
           : Qt.Window | Qt.FramelessWindowHint

    color: "#0d1b26"

    Material.theme: Material.Dark
    Material.accent: "#168df3"
    Material.primary: "#0b1c27"

    font.family: roboto.name

    FontLoader {
        id: roboto
        source: "fonts/Roboto-Regular.ttf"
    }

    FontLoader {
        id: robotoBold
        source: "fonts/Roboto-Bold.ttf"
    }

    property string currentView: "home"
    property string statusMessage: ""
    property string transientMessage: ""

    property bool compactNavigation: width < 700
    property int navigationWidth: compactNavigation ? 52 : 230

    /*
     * Height of our custom desktop title bar.
     */
    property int titleBarHeight: embeddedMode ? 0 : 44

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
            transientMessage =
                    qsTr("Finish or cancel the current operation before leaving this page.")

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

    function openLanguagePage() {
        openFeature("language")
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

    // =====================================================================
    // Application background
    // =====================================================================

    Rectangle {
        anchors.fill: parent
        color: "#0d1b26"
    }

    // =====================================================================
    // CUSTOM TITLE BAR
    // =====================================================================

    Rectangle {
        id: titleBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: window.titleBarHeight

        visible: !window.embeddedMode

        /*
         * Same colour as the main application.
         */
        color: "#0d1b26"

        z: 1000

        // -------------------------------------------------------------
        // Application icon
        // -------------------------------------------------------------

        Image {
            id: titleIcon

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter

            width: 17
            height: 17

            sourceSize.width: 34
            sourceSize.height: 34

            source: "icons/openhdimagewriter.ico"

            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // -------------------------------------------------------------
        // Application title
        // -------------------------------------------------------------

        Text {
            anchors.left: titleIcon.right
            anchors.leftMargin: 9

            anchors.verticalCenter: parent.verticalCenter

            text: qsTr("OpenHD ImageWriter v%1")
                    .arg(imageWriter.constantVersion())

            color: "#9fb0bc"

            font.pixelSize: 13
            font.bold: false
        }

        // -------------------------------------------------------------
        // Drag area
        // -------------------------------------------------------------

        MouseArea {
            id: titleDragArea

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            /*
             * Don't overlap the three window-control buttons.
             */
            anchors.rightMargin: 144

            property real pressX: 0
            property real pressY: 0

            onPressed: {
                pressX = mouse.x
                pressY = mouse.y
            }

            onPositionChanged: {
                if (!pressed)
                    return

                if (window.visibility === Window.Maximized)
                    return

                window.x += mouse.x - pressX
                window.y += mouse.y - pressY
            }

            onDoubleClicked: {
                if (window.visibility === Window.Maximized)
                    window.showNormal()
                else
                    window.showMaximized()
            }
        }

        // -------------------------------------------------------------
        // Window controls
        // -------------------------------------------------------------

        Row {
            id: windowControls

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            z: 10

            // ---------------------------------------------------------
            // Minimize
            // ---------------------------------------------------------

            Button {
                id: minimizeButton

                width: 48
                height: titleBar.height

                padding: 0
                hoverEnabled: true

                background: Rectangle {
                    color: minimizeButton.hovered
                           ? "#172a37"
                           : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }
                }

                contentItem: Item {
                    Rectangle {
                        anchors.centerIn: parent

                        width: 11
                        height: 1

                        color: "#aab7bf"
                    }
                }

                onClicked: window.showMinimized()
            }

            // ---------------------------------------------------------
            // Maximize / Restore
            // ---------------------------------------------------------

            Button {
                id: maximizeButton

                width: 48
                height: titleBar.height

                padding: 0
                hoverEnabled: true

                background: Rectangle {
                    color: maximizeButton.hovered
                           ? "#172a37"
                           : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }
                }

                contentItem: Item {

                    // Normal maximize icon
                    Rectangle {
                        visible: window.visibility !== Window.Maximized

                        anchors.centerIn: parent

                        width: 10
                        height: 10

                        color: "transparent"

                        border.width: 1
                        border.color: "#aab7bf"
                    }

                    // Restore icon
                    Item {
                        visible: window.visibility === Window.Maximized

                        anchors.centerIn: parent

                        width: 13
                        height: 13

                        Rectangle {
                            width: 9
                            height: 9

                            x: 4
                            y: 0

                            color: "#0d1b26"

                            border.width: 1
                            border.color: "#aab7bf"
                        }

                        Rectangle {
                            width: 9
                            height: 9

                            x: 0
                            y: 4

                            color: maximizeButton.hovered
                                   ? "#172a37"
                                   : "#0d1b26"

                            border.width: 1
                            border.color: "#aab7bf"
                        }
                    }
                }

                onClicked: {
                    if (window.visibility === Window.Maximized)
                        window.showNormal()
                    else
                        window.showMaximized()
                }
            }

            // ---------------------------------------------------------
            // Close
            // ---------------------------------------------------------

            Button {
                id: closeButton

                width: 48
                height: titleBar.height

                padding: 0
                hoverEnabled: true

                background: Rectangle {
                    color: closeButton.hovered
                           ? "#c42b1c"
                           : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }
                }

                contentItem: Item {

                    /*
                     * Draw the X instead of relying on a font glyph.
                     */
                    Rectangle {
                        anchors.centerIn: parent

                        width: 13
                        height: 1

                        rotation: 45

                        color: closeButton.hovered
                               ? "#ffffff"
                               : "#aab7bf"
                    }

                    Rectangle {
                        anchors.centerIn: parent

                        width: 13
                        height: 1

                        rotation: -45

                        color: closeButton.hovered
                               ? "#ffffff"
                               : "#aab7bf"
                    }
                }

                onClicked: window.close()
            }
        }
    }

    // =====================================================================
    // MAIN SIDEBAR
    // =====================================================================

    ModernSidebar {
        id: sidebar

        anchors.left: parent.left
        anchors.top: window.embeddedMode
                     ? parent.top
                     : titleBar.bottom

        anchors.bottom: parent.bottom

        width: window.navigationWidth

        currentView: window.currentView

        onNavigate: window.openFeature(view)

        onLanguageRequested:
            window.openLanguagePage()

        onInfoRequested:
            infoPopup.open()

        onHelpRequested:
            Qt.openUrlExternally(
                "https://openhd.gitbook.io/open-hd/"
            )

        Behavior on width {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }

    // =====================================================================
    // MAIN CONTENT SURFACE
    // =====================================================================

    Rectangle {
        id: contentSurface

        anchors.left: sidebar.right
        anchors.right: parent.right

        anchors.top: window.embeddedMode
                     ? parent.top
                     : titleBar.bottom

        anchors.bottom: parent.bottom

        color: "#0d1b26"

        clip: true

        // -----------------------------------------------------------------
        // Home
        // -----------------------------------------------------------------

        ModernHome {
            anchors.fill: parent

            visible: currentView === "home"
            enabled: visible

            statusMessage: window.statusMessage

            onFeatureRequested:
                window.openFeature(view)
        }

        // -----------------------------------------------------------------
        // Flash
        // -----------------------------------------------------------------

        Loader {
            id: flashLoader

            anchors.fill: parent

            source: "flash.qml"
            active: true

            visible: currentView === "flash"
            enabled: visible

            onLoaded:
                item.mainWindow = window
        }

        // -----------------------------------------------------------------
        // Update
        // -----------------------------------------------------------------

        Loader {
            id: updateLoader

            anchors.fill: parent

            source: "update.qml"
            active: true

            visible: currentView === "update"
            enabled: visible

            onLoaded:
                item.mainWindow = window
        }

        // -----------------------------------------------------------------
        // Configure
        // -----------------------------------------------------------------

        Loader {
            id: configureLoader

            anchors.fill: parent

            source: "configure.qml"
            active: true

            visible: currentView === "configure"
            enabled: visible

            onLoaded:
                item.mainWindow = window
        }

        // -----------------------------------------------------------------
        // Language
        // -----------------------------------------------------------------

        LanguageSettingsPage {
            anchors.fill: parent

            visible: currentView === "language"
            enabled: visible

            languages:
                imageWriter.getTranslations()

            currentLanguage:
                imageWriter.getCurrentLanguage()

            onLanguageSelected: {
                imageWriter.changeLanguage(language)
                imageWriter.setSetting(
                    "language",
                    language
                )
            }

            onBackRequested:
                window.showHome()
        }

        // -----------------------------------------------------------------
        // Temporary notification
        // -----------------------------------------------------------------

        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            anchors.topMargin: 18

            width: Math.min(
                       noticeText.implicitWidth + 36,
                       parent.width - 36
                   )

            height: noticeText.implicitHeight + 22

            radius: 7

            color: "#3b3010"

            border.color: "#b58c16"
            border.width: 1

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

    // =====================================================================
    // TRANSIENT MESSAGE TIMER
    // =====================================================================

    Timer {
        id: transientMessageTimer

        interval: 4000

        onTriggered:
            transientMessage = ""
    }

    // =====================================================================
    // INFO POPUP
    // =====================================================================

Popup {
    id: infoPopup

    x: Math.round((window.width - width) / 2)
    y: Math.round((window.height - height) / 2)

    width: Math.min(500, window.width - 40)
    height: Math.min(330, window.height - 40)

    padding: 0

    modal: true
    dim: true

    closePolicy:
        Popup.CloseOnEscape |
        Popup.CloseOnPressOutside

    background: Rectangle {
        radius: 14

        color: "#0d1c2a"

        border.color: "#294754"
        border.width: 1
    }

    contentItem: Item {
        anchors.fill: parent

        // ============================================================
        // Close button
        // ============================================================

        Button {
            id: infoCloseButton

            anchors.top: parent.top
            anchors.right: parent.right

            anchors.topMargin: 10
            anchors.rightMargin: 10

            width: 34
            height: 34

            padding: 0
            hoverEnabled: true

            background: Rectangle {
                radius: 5

                color:
                    infoCloseButton.hovered
                    ? "#173246"
                    : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 80
                    }
                }
            }

            contentItem: Item {
                Rectangle {
                    anchors.centerIn: parent

                    width: 17
                    height: 1.5
                    rotation: 45

                    color:
                        infoCloseButton.hovered
                        ? "#ffffff"
                        : "#7f9bae"
                }

                Rectangle {
                    anchors.centerIn: parent

                    width: 17
                    height: 1.5
                    rotation: -45

                    color:
                        infoCloseButton.hovered
                        ? "#ffffff"
                        : "#7f9bae"
                }
            }

            onClicked: infoPopup.close()
        }

        // ============================================================
        // Main content
        // ============================================================

        ColumnLayout {
            anchors.fill: parent

            anchors.leftMargin: 32
            anchors.rightMargin: 32
            anchors.topMargin: 20
            anchors.bottomMargin: 18

            spacing: 0

            // --------------------------------------------------------
            // Logo
            // --------------------------------------------------------

            Image {
                Layout.alignment: Qt.AlignHCenter

                Layout.preferredWidth: 285
                Layout.preferredHeight: 88

                source: "icons/openhd_imagewriter_logo_v4.png"

                fillMode: Image.PreserveAspectFit

                smooth: true
                antialiasing: true
            }

            Item {
                Layout.preferredHeight: 2
            }

            // --------------------------------------------------------
            // Version
            // --------------------------------------------------------

            Text {
                Layout.fillWidth: true

                text: "v" + imageWriter.constantVersion()

                color: "#91aec2"

                horizontalAlignment: Text.AlignHCenter

                font.pixelSize: 19
                font.bold: true
            }

            Item {
                Layout.preferredHeight: 22
            }

            // --------------------------------------------------------
            // Buttons
            // --------------------------------------------------------

            RowLayout {
                Layout.fillWidth: true

                spacing: 12

            Repeater {
                model: [
                    {
                        "title": qsTr("WEBSITE"),
                        "icon": "icons/ui/website.svg",
                        "url": "https://openhdfpv.org"
                    },
                    {
                        "title": qsTr("GITHUB"),
                        "icon": "icons/ui/github.svg",
                        "url": "https://github.com/OpenHD/OpenHD-ImageWriter"
                    },
                    {
                        "title": qsTr("DONATE"),
                        "icon": "icons/ui/donate.svg",
                        "url": "https://opencollective.com/openhd"
                    }
                ]

                delegate: Button {
                    id: actionButton

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54

                    padding: 0
                    hoverEnabled: true

                    background: Rectangle {
                        radius: 5

                        color:
                            actionButton.down
                            ? "#18384b"
                            : actionButton.hovered
                            ? "#153246"
                            : "#102330"

                        border.width: 1

                        border.color:
                            actionButton.hovered
                            ? "#3d6a84"
                            : "#294b5f"

                        Behavior on color {
                            ColorAnimation {
                                duration: 80
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 80
                            }
                        }
                    }

                    contentItem: Item {
                        anchors.fill: parent

                        Image {
                            id: actionIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter

                            width: 22
                            height: 22

                            source: modelData.icon

                            sourceSize.width: 44
                            sourceSize.height: 44

                            fillMode: Image.PreserveAspectFit

                            smooth: true
                            antialiasing: true

                            opacity:
                                actionButton.hovered
                                ? 1.0
                                : 0.90

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 80
                                }
                            }
                        }

                        Text {
                            anchors.left: actionIcon.right
                            anchors.leftMargin: 10

                            anchors.right: parent.right
                            anchors.rightMargin: 10

                            anchors.verticalCenter: parent.verticalCenter

                            text: modelData.title

                            color: "#e5eef4"

                            font.pixelSize: 12
                            font.bold: true

                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    onClicked:
                        Qt.openUrlExternally(modelData.url)
                }
            }
            }

            // Fill remaining tiny amount of room
            Item {
                Layout.fillHeight: true
            }

            // --------------------------------------------------------
            // Footer
            // --------------------------------------------------------

            Text {
                Layout.fillWidth: true

                text:
                    qsTr(
                        "WRITE   ·   UPDATE   ·   CONFIGURE   ·   FLY"
                    )

                color: "#4f809d"

                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 2.2

                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
}