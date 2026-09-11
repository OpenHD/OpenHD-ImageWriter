/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Window 2.2
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2
import Qt.labs.settings 1.0
import "qmlcomponents"



Rectangle {
    id: window
    anchors.fill: parent
    color: "#0c202c"

    FontLoader {id: roboto;      source: "fonts/Roboto-Regular.ttf"}
    FontLoader {id: robotoLight; source: "fonts/Roboto-Light.ttf"}
    FontLoader {id: robotoBold;  source: "fonts/Roboto-Bold.ttf"}

    property var mainWindow: null
    property url updateManifestUrl: "https://github.com/OpenHD/OpenHD-ImageWriter/releases/download/Json/OpenHD-Update.json"
    property url x21UpdateManifestUrl: "https://dl.cloudsmith.io/public/openhd/dev-release/raw/files/openhd-x21b-updates.json"
    property string selectedUpdateSource: ""
    property string selectedUpdateSubdirectory: "openhd"
    property string selectedUpdateFilename: ""
    property string selectedUpdateSha256: ""
    property double downloadSpeedMbit: 0
    property double lastDownloadBytes: 0
    property double lastDownloadTimestamp: 0
    property double writeSpeedMB: 0
    property double lastWriteBytes: 0
    property double lastWriteTimestamp: 0
    property bool selectingImage: false
    property bool selectingTarget: false
    property bool reviewingOperation: false
    readonly property bool operationInProgress: progressBar.visible
    property bool returnHomeAfterPopupClose: false

    function navigateBack() {
        if (selectingImage) {
            selectingImage = false
            return
        }

        if (selectingTarget) {
            selectingTarget = false
            imageWriter.stopDriveListPolling()
            return
        }

        if (reviewingOperation) {
            reviewingOperation = false
            return
        }

        if (optionsPage.visible) {
            optionsPage.close()
            return
        }

        if (progressBar.visible) {
            quitpopup.openPopup()
            return
        }

        if (mainWindow && mainWindow.showHome) {
            mainWindow.showHome()
        }
    }

    function openUpdateSelector() {
        while (osswipeview.currentIndex > 0)
            osswipeview.decrementCurrentIndex()
        imageCatalog.categorySelected = ""
        resetOpenHdSettingsForNewImage()
        optionsPage.initialized = false
        selectingImage = true
    }

    function returnToOverview() {
        selectingImage = false
        selectingTarget = false
        reviewingOperation = false
        imageWriter.stopDriveListPolling()
        if (optionsPage.visible)
            optionsPage.close()
    }

    function startUpdateNow() {
        langbar.visible = false
        writebutton.enabled = false
        cancelwritebutton.enabled = true
        cancelwritebutton.visible = true
        cancelverifybutton.enabled = true
        resetDownloadTracking()
        progressText.text = qsTr("Preparing update transfer...")
        progressText.visible = true
        progressBar.visible = true
        progressBar.indeterminate = true
        progressBar.Material.accent = "#ffffff"
        osbutton.enabled = false
        dstbutton.enabled = false
        imageWriter.setVerifyEnabled(false)
        imageWriter.startUpdateUpload(selectedUpdateSource, "", selectedUpdateSubdirectory,
                                      selectedUpdateFilename, selectedUpdateSha256)
    }

    Shortcut {
        sequence: StandardKey.Quit
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!progressBar.visible) {
                Qt.quit()
            }
        }
    }

    Shortcut {
        sequences: ["Shift+Ctrl+X", "Shift+Meta+X"]
        context: Qt.ApplicationShortcut
        onActivated: {
            optionsPage.openPage()
        }
    }

    ToolButton {
        id: backButton
        visible: false
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        width: 28
        height: 28
        padding: 4
        hoverEnabled: true
        background: Rectangle { color: "transparent" }
        contentItem: Text {
            text: "\u2190"
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }
        onClicked: navigateBack()
    }

    Flickable {
        id: modernWorkflow
        anchors.fill: parent
        visible: !selectingImage && !selectingTarget && !reviewingOperation && !optionsPage.visible
        enabled: visible
        contentWidth: width
        contentHeight: modernContent.implicitHeight + 72
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: modernContent
            width: Math.min(modernWorkflow.width - (modernWorkflow.width < 700 ? 40 : 72), 1040)
            anchors.horizontalCenter: parent.horizontalCenter
            y: modernWorkflow.width < 700 ? 24 : 38
            spacing: 24

            PageHeader {
                Layout.fillWidth: true
                title: progressBar.visible ? qsTr("Updating device") : qsTr("Update an OpenHD device")
                subtitle: progressBar.visible
                          ? qsTr("Keep the target connected until the update is complete.")
                          : qsTr("Select an update package and target device, then start the installation.")
            }

            GridLayout {
                Layout.fillWidth: true
                visible: !progressBar.visible
                columns: width >= 840 ? 3 : 1
                rowSpacing: 14
                columnSpacing: 14

                ActionCard {
                    Layout.fillWidth: true
                    text: osbutton.text === qsTr("CHOOSE UPDATE") ? qsTr("No update selected") : osbutton.text
                    eyebrow: qsTr("Update package")
                    description: qsTr("Choose a current OpenHD release or select a local update package.")
                    actionText: qsTr("Choose update")
                    iconSource: "icons/ui/update.svg"
                    onClicked: openUpdateSelector()
                }

                ActionCard {
                    Layout.fillWidth: true
                    text: dstbutton.text === qsTr("CHOOSE STORAGE") ? qsTr("No target selected") : dstbutton.text
                    eyebrow: qsTr("Target device")
                    description: qsTr("Select the device or storage that should receive the update.")
                    actionText: qsTr("Choose target")
                    iconSource: "icons/ui/drive.svg"
                    onClicked: {
                        imageWriter.startDriveListPolling()
                        selectingTarget = true
                    }
                }

                ActionCard {
                    Layout.fillWidth: true
                    text: writebutton.enabled ? qsTr("Ready to update") : qsTr("Complete the selections")
                    eyebrow: qsTr("Final step")
                    description: qsTr("Review the package and target before starting the update.")
                    actionText: qsTr("Review and update")
                    iconSource: "icons/ui/write.svg"
                    primaryAction: true
                    enabled: writebutton.enabled
                    onClicked: writebutton.clicked()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: progressPanelContent.implicitHeight + 40
                visible: progressBar.visible
                radius: 10
                color: "#0e2734"
                border.color: "#294754"

                ColumnLayout {
                    id: progressPanelContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: progressText.text
                            color: "#edf5f9"
                            font.pixelSize: 14
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            text: Math.round(progressBar.value * 100) + "%"
                            color: "#5bb4ff"
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        value: progressBar.value
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Do not remove or disconnect the target.")
                            color: "#8299a7"
                            font.pixelSize: 11
                        }

                        Button {
                            visible: cancelwritebutton.visible
                            enabled: cancelwritebutton.enabled
                            text: qsTr("Cancel")
                            onClicked: cancelwritebutton.clicked()
                        }

                        Button {
                            visible: cancelverifybutton.visible
                            enabled: cancelverifybutton.enabled
                            text: qsTr("Skip verification")
                            onClicked: cancelverifybutton.clicked()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                visible: !progressBar.visible
                color: "#213d4a"
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !progressBar.visible

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: qsTr("Update options")
                        color: "#dbe7ed"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: qsTr("Adjust package-specific settings before installing.")
                        color: "#8198a5"
                        font.pixelSize: 11
                    }
                }

                Button {
                    text: qsTr("Configure")
                    onClicked: optionsPage.openPage()
                }
            }
        }
    }

    ImageSelectionPage {
        anchors.fill: parent
        visible: selectingImage
        enabled: visible
        z: 2
        sourceModel: osswipeview.currentItem ? osswipeview.currentItem.model : osmodel
        rootLevel: osswipeview.currentIndex === 0
        categoryName: imageCatalog.categorySelected
        pageTitle: qsTr("Choose an update")
        pageSubtitle: qsTr("Select an official release or a local update package.")
        nestedSubtitle: qsTr("Choose the update release to install.")
        userDefinedTitle: qsTr("Local package")
        onItemSelected: selectOSitem(item)
        onCloseRequested: selectingImage = false
    }

    DeviceSelectionPage {
        anchors.fill: parent
        visible: selectingTarget
        enabled: visible
        z: 2
        deviceModel: driveListModel
        title: qsTr("Choose an update target")
        subtitle: qsTr("Select the device or storage that should receive the update.")
        onDeviceSelected: {
            selectDstItem(device)
            selectingTarget = false
            imageWriter.stopDriveListPolling()
        }
        onBackRequested: {
            selectingTarget = false
            imageWriter.stopDriveListPolling()
        }
        onRefreshRequested: {
            imageWriter.stopDriveListPolling()
            imageWriter.startDriveListPolling()
        }
    }

    OperationReviewPage {
        anchors.fill: parent
        visible: reviewingOperation
        enabled: visible
        z: 2
        title: qsTr("Review device update")
        subtitle: qsTr("Make sure the selected update and destination are correct.")
        sourceName: osbutton.text
        targetName: dstbutton.text
        confirmText: qsTr("Install update")
        updateOperation: true
        onBackRequested: reviewingOperation = false
        onConfirmed: {
            reviewingOperation = false
            startUpdateNow()
        }
    }

    ColumnLayout {
        id: bg
        spacing: 0
        anchors.fill: parent
        opacity: 0
        z: -1



        Rectangle {
            Component.onCompleted: {
                    resetOpenHdSettingsForNewImage()
                }
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(150, Math.min(220, window.height * 0.32))
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
                id: image
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                fillMode: Image.PreserveAspectFit
                source: "icons/logo_stacked_imager.png"
                width: Math.min(window.width * 0.62, 480)
                height: parent.height - 20
            }
        }


        Rectangle {
            color: "#0c202c"
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                id: gridLayout
                rowSpacing: 16

                anchors.fill: parent
                anchors.topMargin: 20
                anchors.bottomMargin: 20
                anchors.rightMargin: window.width < 700 ? 20 : 40
                anchors.leftMargin: window.width < 700 ? 20 : 40

                rows: 6
                columns: window.width >= 760 ? 3 : 1
                columnSpacing: 16

                ColumnLayout {
                    id: columnLayout
                    spacing: 0
                    Layout.fillWidth: true

                    ImButton {
                        id: osbutton
                        text: imageWriter.srcFileName() === "" ? qsTr("CHOOSE UPDATE") : imageWriter.srcFileName()
                        spacing: 0
                        padding: 0
                        bottomPadding: 0
                        topPadding: 0
                        Layout.minimumHeight: 40
                        Layout.fillWidth: true
                        onClicked: {
                            openUpdateSelector()
                        }
                        Accessible.ignored: selectingImage || selectingTarget
                        Accessible.description: qsTr("Select this button to change the operating system")
                    }
                }

                ColumnLayout {
                    id: columnLayout2
                    spacing: 0
                    Layout.fillWidth: true

                    ImButton {
                        id: dstbutton
                        text: qsTr("CHOOSE STORAGE")
                        Layout.minimumHeight: 40
                        Layout.preferredWidth: 100
                        Layout.fillWidth: true
                        onClicked: {
                            imageWriter.startDriveListPolling()
                            selectingTarget = true
                        }
                        Accessible.ignored: selectingImage || selectingTarget
                        Accessible.description: qsTr("Select this button to change the destination storage device")
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true


                    ImButton {
                        id: writebutton
                        visible: !updateButton.visible
                        property var image_name
                        property var use_settings
                        property var bootType
                        property string camera:""
                        text: qsTr("WRITE")
                        Layout.minimumHeight: 40
                        Layout.fillWidth: true
                        Accessible.ignored: selectingImage || selectingTarget
                        Accessible.description: qsTr("Select this button to start writing the image")
                        enabled: false
                        onClicked: {
                            if (!imageWriter.readyToWrite()) {
                                return
                            }
                            image_name=imageWriter.srcFileName();
                            bootType=imageWriter.getValue("bootType");
                            camera=imageWriter.getValue("camera");
                            if(image_name.includes("configurable")){
                                if(bootType!=="Air" && bootType!=="Ground" ){
                                    console.log("Cannot write yet, air or ground not set yet");
                                    onError("Cannot write yet, air or ground not set yet - please open settings and select air or ground")
                                    return;
                                }
                            }
                            use_settings=imageWriter.getValue("useSettings")
                            if (!optionsPage.initialized && imageWriter.imageSupportsCustomization() && imageWriter.hasSavedCustomizationSettings()) {
                                optionsPage.openPage()
                            } else {
                                reviewingOperation = true
                            }
                        }
                    }
                    ImButton {
                        id: updateButton
                        visible: false
                        property var image_name
                        property var use_settings
                        property var bootType
                        property string camera:""

                        text: qsTr("UPDATE")
                        Layout.minimumHeight: 40
                        Layout.fillWidth: true
                        Accessible.ignored: selectingImage || selectingTarget
                        Accessible.description: qsTr("Select this button to start writing the image")
                        enabled: false
                        onClicked: {
                            if (!imageWriter.readyToWrite()) {
                                return
                            }
                            image_name=imageWriter.srcFileName();
                            bootType=imageWriter.getValue("bootType");
                            camera=imageWriter.getValue("camera");
                            if(image_name.includes("configurable")){
                                if(bootType!=="Air" && bootType!=="Ground" ){
                                    console.log("Cannot write yet, air or ground not set yet");
                                    onError("Cannot write yet, air or ground not set yet - please open settings and select air or ground")
                                    return;
                                }
                            }
                            use_settings=imageWriter.getValue("useSettings")
                            if (!optionsPage.initialized && imageWriter.imageSupportsCustomization() && imageWriter.hasSavedCustomizationSettings()) {
                                optionsPage.openPage()
                            } else {
                                reviewingOperation = true
                            }
                        }
                    }

                }

                ColumnLayout {
                    id: columnLayout3
                    Layout.columnSpan: gridLayout.columns
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    Text {
                        id: progressText
                        font.pointSize: 10
                        color: "white"
                        font.family: robotoBold.name
                        font.bold: true
                        visible: false
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    ProgressBar {
                        id: progressBar
                        Layout.fillWidth: true
                        visible: false
                        Material.background: "#00b3f7"
                    }

                    ImButton {
                        id: cancelwritebutton
                        text: qsTr("CANCEL WRITE")
                        onClicked: {
                            enabled = false
                            progressText.text = qsTr("Cancelling...")
                            imageWriter.cancelWrite()
                        }
                        Layout.alignment: Qt.AlignRight
                        visible: false
                    }
                    ImButton {
                        id: cancelverifybutton
                        text: qsTr("CANCEL VERIFY")
                        onClicked: {
                            enabled = false
                            progressText.text = qsTr("Finalizing...")
                            imageWriter.setVerifyEnabled(false)
                        }
                        Layout.alignment: Qt.AlignRight
                        visible: false
                    }
                    ImButton {
                        Layout.bottomMargin: 55
                        padding: 5
                        id: customizebutton
                        onClicked: {
                            optionsPage.openPage()
                        }
                        visible: true
                        Accessible.description: qsTr("Select this button to configure Settings")
                        contentItem: Image {
                            source: "icons/ic_cog_red.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                }

                Text {
                    Layout.columnSpan: gridLayout.columns
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.family: roboto.name
                    visible: imageWriter.isEmbeddedMode() && imageWriter.customRepo()
                    text: qsTr("Using custom repository: %1").arg(imageWriter.constantOsListUrl())
                }

                Text {
                    Layout.columnSpan: gridLayout.columns
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.family: roboto.name
                    visible: !imageWriter.hasMouse()
                    text: qsTr("Keyboard navigation: <tab> navigate to next button <space> press button/select item <arrow up/down> go up/down in lists")
                }

                RowLayout {
                    id: langbar
                    Layout.columnSpan: gridLayout.columns
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                    Layout.bottomMargin: 5
                    spacing: 10
                    visible: imageWriter.isEmbeddedMode()

                    Rectangle {
                        color: "#ffffe3"
                        radius: 5
                    }

                    Text {
                        font.pixelSize: 12
                        font.family: roboto.name
                        text: qsTr("Language: ")
                        Layout.leftMargin: 30
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                    }
                    ComboBox {
                        font.pixelSize: 12
                        font.family: roboto.name
                        model: imageWriter.getTranslations()
                        Layout.preferredWidth: 200
                        currentIndex: -1
                        Component.onCompleted: {
                            var currentLang = imageWriter.getCurrentLanguage()
                            currentIndex = find(currentLang)
                            imageWriter.setSetting("language", currentLang)
                        }
                        onActivated: {
                            imageWriter.changeLanguage(editText)
                            imageWriter.setSetting("language", editText)
                        }
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                    }
                    Text {
                        font.pixelSize: 12
                        font.family: roboto.name
                        text: qsTr("Keyboard: ")
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                    }
                    ComboBox {
                        enabled: imageWriter.isEmbeddedMode()
                        font.pixelSize: 12
                        font.family: roboto.name
                        model: imageWriter.getKeymapLayoutList()
                        currentIndex: -1
                        Component.onCompleted: {
                            currentIndex = find(imageWriter.getCurrentKeyboard())
                        }
                        onActivated: {
                            imageWriter.changeKeyboard(editText)
                        }
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                        Layout.rightMargin: 30
                    }
                }

                /* Language/keyboard bar is normally only visible in embedded mode.
                   To test translations also show it when shift+ctrl+L is pressed. */
                Shortcut {
                    sequences: ["Shift+Ctrl+L", "Shift+Meta+L"]
                    context: Qt.ApplicationShortcut
                    onActivated: {
                        langbar.visible = true
                    }
                }
            }
        }
    }

    // Nonvisual navigation state used by the full-page image catalog.
    Item {
        id: imageCatalog
        visible: false
        property string categorySelected: ""

        SwipeView {
            id: osswipeview
            visible: false
            interactive: false

            ListView {
                id: oslist
                model: osmodel
                currentIndex: -1
            }
        }
    }

    Component {
        id: suboslist

        ListView {
            model: ListModel {
                ListElement {
                    url: ""
                    icon: "icons/ic_chevron_left_40px.svg"
                    extract_size: 0
                    image_download_size: 0
                    extract_sha256: ""
                    contains_multiple_files: false
                    release_date: ""
                    subitems_url: "internal://back"
                    subitems_json: ""
                    name: qsTr("Back")
                    description: qsTr("Go back to main menu")
                    tooltip: ""
                    website: ""
                    init_format: ""
                }
            }
            currentIndex: -1
        }
    }
    ListModel {
        id: osmodel

        ListElement {
            url: "internal://format"
            icon: "icons/erase.png"
            extract_size: 0
            image_download_size: 0
            extract_sha256: ""
            contains_multiple_files: false
            release_date: ""
            subitems_url: ""
            subitems_json: ""
            name: qsTr("Erase")
            description: qsTr("Format card as FAT32")
            tooltip: ""
            website: ""
            init_format: ""
        }

        ListElement {
            url: ""
            icon: "icons/use_custom.png"
            name: qsTr("Use custom")
            description: qsTr("Select a custom .img from your computer")
        }

        Component.onCompleted: {
            if (imageWriter.isOnline()) {
                fetchOSlist();
            }
        }
    }

    MsgPopup {
        id: msgpopup
        onConfigure: {
            var component = Qt.createComponent("configure.qml")
            if (component.status === Component.Ready) {
                component.createObject(null)
            } else if (component.status === Component.Error) {
                console.error(component.errorString())
            }
            window.close()
        }
        onClosed: {
            if (returnHomeAfterPopupClose) {
                returnHomeAfterPopupClose = false
                navigateBack()
            }
        }
    }
    MsgPopup {
        id: quitpopup
        continueButton: false
        yesButton: true
        noButton: true
        title: qsTr("Are you sure you want to quit?")
        text: qsTr("OpenHD ImageWriter is still busy.<br>Are you sure you want to quit?")
        onYes: {
            Qt.quit()
        }
    }

    MsgPopup {
        id: updatepopup
        continueButton: false
        yesButton: true
        noButton: true
        property url url
        title: qsTr("Update available")
        text: qsTr("There is a newer version of the ImageWriter is available.<br>Would you like to visit the website to download it?")
        onYes: {
            Qt.openUrlExternally(url)
        }
    }

    ImageOptionsPage {
        id: optionsPage
    }

    function resetDownloadTracking() {
        downloadSpeedMbit = 0
        lastDownloadBytes = 0
        lastDownloadTimestamp = 0
        writeSpeedMB = 0
        lastWriteBytes = 0
        lastWriteTimestamp = 0
    }

    function updateDownloadSpeed(currentBytes) {
        var nowMs = Date.now()
        if (!lastDownloadTimestamp) {
            lastDownloadTimestamp = nowMs
            lastDownloadBytes = currentBytes
            downloadSpeedMbit = 0
            return
        }

        var elapsedSeconds = (nowMs - lastDownloadTimestamp) / 1000
        if (elapsedSeconds > 0 && currentBytes >= lastDownloadBytes) {
            var bitsPerSecond = (currentBytes - lastDownloadBytes) * 8 / elapsedSeconds
            downloadSpeedMbit = bitsPerSecond / 1000000
        }

        lastDownloadTimestamp = nowMs
        lastDownloadBytes = currentBytes
    }

    function updateWriteSpeed(currentBytes) {
        var nowMs = Date.now()
        if (!lastWriteTimestamp) {
            lastWriteTimestamp = nowMs
            lastWriteBytes = currentBytes
            writeSpeedMB = 0
            return
        }

        var elapsedSeconds = (nowMs - lastWriteTimestamp) / 1000
        if (elapsedSeconds > 0 && currentBytes >= lastWriteBytes) {
            var bytesPerSecond = (currentBytes - lastWriteBytes) / elapsedSeconds
            writeSpeedMB = bytesPerSecond / (1024 * 1024)
        }

        lastWriteTimestamp = nowMs
        lastWriteBytes = currentBytes
    }

    /* Utility functions */
    function httpRequest(url, callback, errorCallback) {
        var xhr = new XMLHttpRequest();
        xhr.timeout = 5000
        xhr.onreadystatechange = (function(x) {
            return function() {
                if (x.readyState === x.DONE)
                {
                    if (x.status === 200)
                    {
                        callback(x)
                    }
                    else
                    {
                        if (errorCallback)
                            errorCallback()
                        else
                            onError(qsTr("Error downloading OS list from Internet"))
                    }
                }
            }
        })(xhr)
        xhr.open("GET", url)
        xhr.send()
    }

    /* Slots for signals imagewrite emits */
    function onDownloadProgress(now,total) {
        var newPos
        if (total) {
            newPos = now/(total+1)
        } else {
            newPos = 0
        }
        if (progressBar.value !== newPos) {
            if (progressText.text === qsTr("Cancelling..."))
                return

            updateDownloadSpeed(now)
            progressText.text = qsTr("Writing... %1% (%2 Mbit/s)").arg(Math.floor(newPos*100)).arg(downloadSpeedMbit.toFixed(1))
            progressBar.indeterminate = false
            progressBar.value = newPos
        }
    }

    function onWriteProgress(now,total) {
        var newPos
        if (total) {
            newPos = now/total
        } else {
            newPos = 0
        }
        if (progressBar.value !== newPos) {
            if (progressText.text === qsTr("Cancelling..."))
                return

            updateWriteSpeed(now)
            progressText.text = qsTr("Writing... %1% (%2 MB/s)").arg(Math.floor(newPos*100)).arg(writeSpeedMB.toFixed(1))
            progressBar.indeterminate = false
            progressBar.value = newPos
        }
    }

    function onUpdateUploadProgress(progress) {
        if (progressText.text === qsTr("Cancelling..."))
            return

        progressText.text = qsTr("Copying update... %1%").arg(Math.floor(progress*100))
        progressBar.indeterminate = false
        progressBar.Material.accent = "#6cc04a"
        progressBar.value = progress
    }

    function onUpdateUploadStatus(msg) {
        progressText.text = msg
    }

    function onVerifyProgress(now,total) {
        var newPos
        if (total) {
            newPos = now/total
        } else {
            newPos = 0
        }

        if (progressBar.value !== newPos) {
            if (cancelwritebutton.visible) {
                cancelwritebutton.visible = false
                cancelverifybutton.visible = true
            }

            if (progressText.text === qsTr("Finalizing..."))
                return

            progressText.text = qsTr("Verifying... %1%").arg(Math.floor(newPos*100))
            progressBar.Material.accent = "#6cc04a"
            progressBar.value = newPos
        }
    }

    function onPreparationStatusUpdate(msg) {
        progressText.text = qsTr("Preparing to write... (%1)").arg(msg)
    }

    function resetWriteButton() {
        progressText.visible = false
        progressBar.visible = false
        resetDownloadTracking()
        osbutton.enabled = true
        dstbutton.enabled = true
        writebutton.visible = true
        writebutton.enabled = imageWriter.readyToWrite()
        cancelwritebutton.visible = false
        cancelverifybutton.visible = false
    }

    function resetOpenHdSettingsForNewImage() {
        imageWriter.setSetting("sbc", "")
        imageWriter.setSetting("bootType", "")
        imageWriter.setSetting("fileName", "")
        imageWriter.setSetting("camera", "")
        imageWriter.setSetting("camera2", "")
        imageWriter.setSetting("cameraResolution", "")
        imageWriter.setSetting("camera2Resolution", "")
        imageWriter.setSetting("mode", "")
        imageWriter.setSetting("hotSpot" , "")
        imageWriter.setSetting("beep", "")
        imageWriter.setSetting("eject", "")
        imageWriter.setSetting("justUpdate", "")
        imageWriter.setSetting("qopenhdConfPath", "")
        selectedUpdateSource = ""
        selectedUpdateSubdirectory = "openhd"
        selectedUpdateFilename = ""
        selectedUpdateSha256 = ""
    }

    function resetWorkflowAfterSuccess() {
        resetOpenHdSettingsForNewImage()
        optionsPage.initialized = false
        imageWriter.setSrc("")
        imageWriter.setDst("")
        osbutton.text = qsTr("CHOOSE UPDATE")
        dstbutton.text = qsTr("CHOOSE STORAGE")
    }

    function onError(msg) {
        returnHomeAfterPopupClose = false
        msgpopup.title = qsTr("Error")
        msgpopup.configureButton = false
        msgpopup.closeButton = false
        msgpopup.text = msg
        msgpopup.openPopup()
        resetWriteButton()
    }

    function onUpdateUploadError(msg) {
        onError(msg)
    }

    function onSuccess() {
        msgpopup.title = qsTr("Image was written successfully!")
        msgpopup.configureButton = false
        msgpopup.closeButton = false
        if (osbutton.text === qsTr("Erase"))
            msgpopup.text = qsTr("<b>%1</b> has been erased<br><br> You can now remove the SD card from the reader").arg(dstbutton.text)
        else if (imageWriter.isEmbeddedMode()) {
            //msgpopup.text = qsTr("<b>%1</b> has been written to <b>%2</b>").arg(osbutton.text).arg(dstbutton.text)
            /* Just reboot to the installed OS */
            Qt.quit()
        }
        else
            msgpopup.text = qsTr("<b>%1</b> has been written to <b>%2</b>! You can now remove the SD card from the reader").arg(osbutton.text).arg(dstbutton.text)
        msgpopup.continueButton = false
        msgpopup.detailsButton = true
        if (imageWriter.isEmbeddedMode()) {
            msgpopup.continueButton = false
            msgpopup.quitButton = true
        }

        msgpopup.openPopup()
        resetWorkflowAfterSuccess()
        resetWriteButton()
    }

    function onUpdateUploadSuccess() {
        var isRockusb = (imageWriter.dst().indexOf("rockusb:") === 0);
        msgpopup.title = qsTr("Update complete")
        if (isRockusb) {
            msgpopup.text = qsTr("<b>%1</b> was flashed to the board.<br>The board is now rebooting.").arg(osbutton.text)
        } else {
            msgpopup.text = qsTr("<b>%1</b> was copied to the FAT32 partition on <b>%2</b>.<br>You can now safely remove the card and insert it into your board.").arg(osbutton.text).arg(dstbutton.text)
        }
        msgpopup.continueButton = true
        msgpopup.detailsButton = false
        msgpopup.configureButton = false
        msgpopup.closeButton = false
        msgpopup.quitButton = false
        returnHomeAfterPopupClose = true
        msgpopup.openPopup()
        resetWriteButton()
    }

    function onFileSelected(file) {
        var normalized = file
        if (typeof file === "string") {
            if (file.indexOf("file:") !== 0) {
                normalized = "file:///" + file.replace(/\\/g, "/")
            }
        }
        imageWriter.setSrc(normalized)
        selectedUpdateSource = normalized
        var lower = normalized.toLowerCase()
        if (lower.endsWith(".ohd")) {
            selectedUpdateSubdirectory = ""
            selectedUpdateFilename = ""
        } else {
            selectedUpdateSubdirectory = "openhd"
            selectedUpdateFilename = ""
        }
        selectedUpdateSha256 = ""
        osbutton.text = imageWriter.srcFileName()
        selectingImage = false
        selectingImage = false
        if (imageWriter.readyToWrite()) {
            writebutton.enabled = true
        }
    }

    function onCancelled() {
        resetWriteButton()
    }

    function onFinalizing() {
        progressText.text = qsTr("Finalizing...")
    }

    function shuffle(arr) {
        for (var i = 0; i < arr.length - 1; i++) {
            var j = i + Math.floor(Math.random() * (arr.length - i));

            var t = arr[j];
            arr[j] = arr[i];
            arr[i] = t;
        }
    }

    function checkForRandom(list) {
        for (var i in list) {
            var entry = list[i]

            if ("subitems" in entry) {
                checkForRandom(entry["subitems"])
                if ("random" in entry && entry["random"]) {
                    shuffle(entry["subitems"])
                }
            }
        }
    }

    function oslistFromJson(o) {
        var oslist = false
        var lang_country = Qt.locale().name
        if ("os_list_"+lang_country in o) {
            oslist = o["os_list_"+lang_country]
        }
        else if (lang_country.includes("_")) {
            var lang = lang_country.substr(0, lang_country.indexOf("_"))
            if ("os_list_"+lang in o) {
                oslist = o["os_list_"+lang]
            }
        }

        if (!oslist) {
            if (!"os_list" in o) {
                onError(qsTr("Error parsing os_list.json"))
                return false
            }

            oslist = o["os_list"]
        }

        checkForRandom(oslist)

        /* Flatten subitems to subitems_json */
        for (var i in oslist) {
            var entry = oslist[i];
            if ("subitems" in entry) {
                entry["subitems_json"] = JSON.stringify(entry["subitems"])
                delete entry["subitems"]
            }
        }

        return oslist
    }

    function selectNamedOS(name, collection)
    {
        for (var i = 0; i < collection.count; i++) {
            var os = collection.get(i)

            if (typeof(os.subitems_json) == "string" && os.subitems_json != "") {
                selectNamedOS(name, os.subitems_json)
            }
            else if (typeof(os.url) !== "undefined" && name === os.name) {
                selectOSitem(os, false)
                break
            }
        }
    }

    function populateOsList(o) {
        var oslist = oslistFromJson(o)
        if (oslist === false)
            return
        for (var i in oslist) {
            osmodel.insert(osmodel.count-2, oslist[i])
        }

        if ("imager" in o) {
            var imager = o["imager"]
            if (imageWriter.getBoolSetting("check_version") && "latest_version" in imager && "url" in imager) {
                if (!imageWriter.isEmbeddedMode() && imageWriter.isVersionNewer(imager["latest_version"])) {
                    updatepopup.url = imager["url"]
                    updatepopup.openPopup()
                }
            }
            if ("default_os" in imager) {
                selectNamedOS(imager["default_os"], osmodel)
            }
            if (imageWriter.isEmbeddedMode()) {
                if ("embedded_default_os" in imager) {
                    selectNamedOS(imager["embedded_default_os"], osmodel)
                }
                if ("embedded_default_destination" in imager) {
                    imageWriter.startDriveListPolling()
                    setDefaultDest.drive = imager["embedded_default_destination"]
                    setDefaultDest.start()
                }
            }
        }
    }

    function fetchOSlist() {
        function loadLocalUpdates() {
            httpRequest(Qt.resolvedUrl("OpenHD-Update.json"), function (local) {
                populateOsList(JSON.parse(local.responseText))
            }, function() { onError(qsTr("Error downloading OS list from Internet")) })
        }

        httpRequest(updateManifestUrl, function (x) {
            populateOsList(JSON.parse(x.responseText))
        }, loadLocalUpdates)

        httpRequest(x21UpdateManifestUrl, function (x) {
            populateOsList(JSON.parse(x.responseText))
        }, function() { console.log("X21 update catalog is not available") })
    }

    Timer {
        /* Verify if default drive is in our list after 100 ms */
        id: setDefaultDest
        property string drive : ""
        interval: 100
        onTriggered: {
            for (var i = 0; i < driveListModel.rowCount(); i++)
            {
                /* FIXME: there should be a better way to iterate drivelist than
                   fetch data by numeric role number */
                if (driveListModel.data(driveListModel.index(i,0), 0x101) === drive) {
                    selectDstItem({
                                      device: drive,
                                      description: driveListModel.data(driveListModel.index(i,0), 0x102),
                                      size: driveListModel.data(driveListModel.index(i,0), 0x103),
                                      readonly: false
                                  })
                    break
                }
            }
        }
    }

    function newSublist() {
        if (osswipeview.currentIndex == (osswipeview.count-1))
        {
            var newlist = suboslist.createObject(osswipeview)
            osswipeview.addItem(newlist)
        }

        var m = osswipeview.itemAt(osswipeview.currentIndex+1).model

        if (m.count>1)
        {
            m.remove(1, m.count-1)
        }

        return m
    }

    function selectOSitem(d, selectFirstSubitem)
    {
        if (typeof(d.subitems_json) == "string" && d.subitems_json !== "") {
            var m = newSublist()
            var subitems = JSON.parse(d.subitems_json)

            for (var i in subitems)
            {
                var entry = subitems[i];
                if ("subitems" in entry) {
                    /* Flatten sub-subitems entry */
                    entry["subitems_json"] = JSON.stringify(entry["subitems"])
                    delete entry["subitems"]
                }
                m.append(entry)
            }

            osswipeview.itemAt(osswipeview.currentIndex+1).currentIndex = (selectFirstSubitem === true) ? 0 : -1
            osswipeview.incrementCurrentIndex()
            imageCatalog.categorySelected = d.name
        } else if (typeof(d.subitems_url) == "string" && d.subitems_url !== "") {
            if (d.subitems_url === "internal://back")
            {
                osswipeview.decrementCurrentIndex()
                imageCatalog.categorySelected = ""
            }
            else
            {
                imageCatalog.categorySelected = d.name
                var suburl = d.subitems_url
                var m = newSublist()

                httpRequest(suburl, function (x) {
                    var o = JSON.parse(x.responseText)
                    var oslist = oslistFromJson(o)
                    if (oslist === false)
                        return
                    for (var i in oslist) {
                        m.append(oslist[i])
                    }
                }, function() { onError(qsTr("Error downloading OS list from Internet")) })

                osswipeview.itemAt(osswipeview.currentIndex+1).currentIndex = (selectFirstSubitem === true) ? 0 : -1
                osswipeview.incrementCurrentIndex()
            }
        } else if (d.url === "") {
            if (!imageWriter.isEmbeddedMode()) {
                imageWriter.openFileDialog()
            }
            else {
                if (imageWriter.mountUsbSourceMedia()) {
                    var m = newSublist()

                    var oslist = JSON.parse(imageWriter.getUsbSourceOSlist())
                    for (var i in oslist) {
                        m.append(oslist[i])
                    }
                    osswipeview.itemAt(osswipeview.currentIndex+1).currentIndex = (selectFirstSubitem === true) ? 0 : -1
                    osswipeview.incrementCurrentIndex()
                }
                else
                {
                    onError(qsTr("Connect an USB stick containing images first.<br>The images must be located in the root folder of the USB stick."))
                }
            }
        } else {
            imageWriter.setSrc(d.url, d.image_download_size, d.extract_size, typeof(d.extract_sha256) != "undefined" ? d.extract_sha256 : "", typeof(d.contains_multiple_files) != "undefined" ? d.contains_multiple_files : false, imageCatalog.categorySelected, d.name, typeof(d.init_format) != "undefined" ? d.init_format : "")
            selectedUpdateSource = d.url
            selectedUpdateSubdirectory = (typeof(d.update_destination) != "undefined" && d.update_destination === "root") ? "" : "openhd"
            selectedUpdateFilename = typeof(d.update_filename) != "undefined" ? d.update_filename : ""
            selectedUpdateSha256 = typeof(d.update_sha256) != "undefined" ? d.update_sha256 : ""
            osbutton.text = d.name
            selectingImage = false
            if (imageWriter.readyToWrite()) {
                writebutton.enabled = true
            }
        }
    }

    function selectDstItem(d) {
        if (d.isReadOnly) {
            onError(qsTr("SD card is write protected.<br>Push the lock switch on the left side of the card upwards, and try again."))
            return
        }

        selectingTarget = false
        imageWriter.stopDriveListPolling()
        imageWriter.setDst(d.device, d.size)
        dstbutton.text = d.description
        if (imageWriter.readyToWrite()) {
            writebutton.enabled = true
        }
    }
}
