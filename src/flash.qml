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
    property double downloadSpeedMB: 0
    property double lastDownloadBytes: 0
    property double lastDownloadTimestamp: 0
    property double writeSpeedMB: 0
    property double lastWriteBytes: 0
    property double lastWriteTimestamp: 0

    function navigateBack() {
        if (progressBar.visible) {
            quitpopup.openPopup()
            return
        }

        if (mainWindow && mainWindow.showHome) {
            mainWindow.showHome()
        }
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
            optionspopup.openPopup()
        }
    }

    ToolButton {
        id: backButton
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

    Popup {
        id: detailsPopup
        x: 75
        y: (parent.height - height) / 2
        width: parent.width - 150
        height: parent.implicitHeight + 275
        padding: 0
        modal: true
        property bool objectVisible: false
        visible: objectVisible

        Rectangle {
            color: "#f5f5f5"
            anchors.right: parent.right
            anchors.top: parent.top
            height: 35
            width: parent.width
        }
        Rectangle {
            color: "#afafaf"
            width: parent.width
            y: 35
            implicitHeight: 1
        }
        Settings {
            id: appSettings
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
                    detailsPopup.close()
                }
            }
        }

        ColumnLayout {
            spacing: 20
            anchors.fill: parent

            Text {
                id: detailsPopupHeader
                text: "List of applied settings and variables"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
                font.family: roboto.name
                font.bold: true
            }
            Button{
                id:refresh
                visible:false
                text: "button"
                onClicked: {
                    console.log(imageWriter.getValue("fileName"))
                }
            }

            ColumnLayout {
                id: detailsArea
                spacing: 10
                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: -30
                Layout.leftMargin: 20

                RowLayout {
                    Text {
                        text: "Image Name:"
                        font.bold: true
                    }

                    Text {
                        text: {
                            if (typeof optionspopup.fileName !== "undefined" && optionspopup.fileName.length > 45) {
                                return optionspopup.fileName.substring(0, optionspopup.fileName.length - 7);
                            }else if (typeof optionspopup.fileName !== "undefined" && optionspopup.fileName.length > 1){
                                return optionspopup.fileName.substring(0, optionspopup.fileName.length);
                            }else {
                                return "Error";
                            }
                        }
                        font.bold: false
                        color: "grey"
                    }
                }


                // RowLayout {
                //     Text {
                //         text: "sbc:"
                //         font.bold: true
                //     }

                //     Text {
                //         text: optionspopup.sbc
                //         font.bold: false
                //         color: "grey"

                //     }
                // }

                RowLayout {
                    Text {
                        text: "Boot Type:"
                        font.bold: true
                    }
                    Text {
                        text: optionspopup.bootType + "  " + optionspopup.mode
                        font.bold: false
                        color: "grey"
                    }
                }

                RowLayout {
                    Text {
                        text: "Camera:"
                        font.bold: true
                    }
                    Text {
                        text: optionspopup.camera
                        font.bold: false
                        color: "grey"
                    }
                }

                RowLayout {
                    Text {
                        text: "Camera 2:"
                        font.bold: true
                    }
                    Text {
                        text: optionspopup.camera2
                        font.bold: false
                        color: "grey"
                    }
                }

                RowLayout {
                    Text {
                        text: "Camera Res:"
                        font.bold: true
                    }
                    Text {
                        text: optionspopup.cameraResolution
                        font.bold: false
                        color: "grey"
                    }
                }

                RowLayout {
                    Text {
                        text: "Camera 2 Res:"
                        font.bold: true
                    }
                    Text {
                        text: optionspopup.camera2Resolution
                        font.bold: false
                        color: "grey"
                    }
                }

                RowLayout {
                    Text {
                        text: "Changelog:"
                        font.bold: true
                    }
                    Text {
                        text: "<a href='https://openhdfpv.org/2.5-evo.html'>changelogs</a>"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Qt.openUrlExternally("https://openhdfpv.org/2.5-evo.html")
                        }
                        font.bold:false
                        color: "grey"
                    }
                }
            }
        }
    }


    ColumnLayout {
        id: bg
        spacing: 0
        anchors.fill: parent

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
                    Layout.alignment: Qt.AlignTop

                    ImButton {
                        id: osbutton
                        text: imageWriter.srcFileName() === "" ? qsTr("CHOOSE OS") : imageWriter.srcFileName()
                        spacing: 0
                        padding: 0
                        bottomPadding: 0
                        topPadding: 0
                        Layout.minimumHeight: 40
                        Layout.fillWidth: true
                        onClicked: {
                            ospopup.open()
                            osswipeview.currentItem.forceActiveFocus()
                            resetOpenHdSettingsForNewImage()
                            optionspopup.initialized = false
                        }
                        Accessible.ignored: ospopup.visible || dstpopup.visible
                        Accessible.description: qsTr("Select this button to change the operating system")
                    }
                }

                ColumnLayout {
                    id: columnLayout2
                    spacing: 0
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    ImButton {
                        id: dstbutton
                        text: qsTr("CHOOSE STORAGE")
                        Layout.minimumHeight: 40
                        Layout.preferredWidth: 100
                        Layout.fillWidth: true
                        onClicked: {
                            imageWriter.startDriveListPolling()
                            dstpopup.open()
                            dstlist.forceActiveFocus()
                        }
                        Accessible.ignored: ospopup.visible || dstpopup.visible
                        Accessible.description: qsTr("Select this button to change the destination storage device")
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

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
                        Accessible.ignored: ospopup.visible || dstpopup.visible
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
                            if (!optionspopup.initialized && imageWriter.imageSupportsCustomization() && imageWriter.hasSavedCustomizationSettings()) {
                                usesavedsettingspopup.openPopup()
                            } else {
                                confirmwritepopup.askForConfirmation()
                            }
                        }
                    }
                    ImButton {
                        id: updateButton
                        visible:ospopup.visible
                        property var image_name
                        property var use_settings
                        property var bootType
                        property string camera:""

                        text: qsTr("UPDATE")
                        Layout.minimumHeight: 40
                        Layout.fillWidth: true
                        Accessible.ignored: ospopup.visible || dstpopup.visible
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
                            if (!optionspopup.initialized && imageWriter.imageSupportsCustomization() && imageWriter.hasSavedCustomizationSettings()) {
                                usesavedsettingspopup.openPopup()
                            } else {
                                confirmwritepopup.askForConfirmation()
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
                            optionspopup.openPopup()
                        }
                        visible: !progressBar.visible && !cancelwritebutton.visible && !cancelverifybutton.visible
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

    /*
      Popup for OS selection
     */
    Popup {
        id: ospopup
        x: 50
        y: 25
        width: parent.width-100
        height: parent.height-50
        padding: 0
        closePolicy: Popup.NoAutoClose
        property string categorySelected : ""

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
                    ospopup.close()
                }
            }
        }

        ColumnLayout {
            spacing: 10

            Text {
                text: qsTr("Operating System")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
                Layout.topMargin: 10
                font.family: roboto.name
                font.bold: true
            }

            Item {
                clip: true
                Layout.preferredWidth: oslist.width
                Layout.preferredHeight: oslist.height

                SwipeView {
                    id: osswipeview
                    interactive: false

                    ListView {
                        id: oslist
                        model: osmodel
                        currentIndex: -1
                        delegate: osdelegate
                        width: window.width-100
                        height: window.height-100
                        boundsBehavior: Flickable.StopAtBounds
                        highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
                        ScrollBar.vertical: ScrollBar {
                            width: 10
                            policy: oslist.contentHeight > oslist.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        }
                        Keys.onSpacePressed: {
                            if (currentIndex != -1)
                                selectOSitem(model.get(currentIndex), true)
                        }
                        Accessible.onPressAction: {
                            if (currentIndex != -1)
                                selectOSitem(model.get(currentIndex), true)
                        }
                        Keys.onEnterPressed: Keys.onSpacePressed(event)
                        Keys.onReturnPressed: Keys.onSpacePressed(event)
                    }
                }
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
            delegate: osdelegate
            width: window.width-100
            height: window.height-100
            boundsBehavior: Flickable.StopAtBounds
            highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
            ScrollBar.vertical: ScrollBar {
                width: 10
                policy: parent.contentHeight > parent.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }
            Keys.onSpacePressed: {
                if (currentIndex != -1)
                    selectOSitem(model.get(currentIndex))
            }
            Accessible.onPressAction: {
                if (currentIndex != -1)
                    selectOSitem(model.get(currentIndex))
            }
            Keys.onEnterPressed: Keys.onSpacePressed(event)
            Keys.onReturnPressed: Keys.onSpacePressed(event)
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

    Component {
        id: osdelegate

        Item {
            width: window.width-100
            height: contentLayout.implicitHeight + 24
            Accessible.name: name+".\n"+description

            MouseArea {
                id: osMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onEntered: {
                    bgrect.mouseOver = true
                }

                onExited: {
                    bgrect.mouseOver = false
                }

                onClicked: {
                    selectOSitem(model)
                }
            }

            Rectangle {
                id: bgrect
                anchors.fill: parent
                color: "#f5f5f5"
                visible: mouseOver && parent.ListView.view.currentIndex !== index
                property bool mouseOver: false
            }
            Rectangle {
                id: borderrect
                implicitHeight: 1
                implicitWidth: parent.width
                color: "#dcdcdc"
                y: parent.height
            }

            RowLayout {
                id: contentLayout
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                    margins: 12
                }
                spacing: 12

                Image {
                    source: icon == "icons/ic_build_48px.svg" ? "icons/cat_misc_utility_images.png": icon
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 40
                    sourceSize.width: 40
                    sourceSize.height: 40
                    fillMode: Image.PreserveAspectFit
                    verticalAlignment: Image.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                }
                ColumnLayout {
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 12
                        Text {
                            text: name
                            elide: Text.ElideRight
                            font.family: roboto.name
                            font.bold: true
                        }
                        Image {
                            source: "icons/ic_info_16px.png"
                            Layout.preferredHeight: 16
                            Layout.preferredWidth: 16
                            visible: typeof(website) == "string" && website
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Qt.openUrlExternally(website)
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        font.family: roboto.name
                        text: description
                        wrapMode: Text.WordWrap
                        color: "#1a1a1a"
                    }

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: "#646464"
                        font.weight: Font.Light
                        visible: typeof(release_date) == "string" && release_date
                        text: qsTr("Released: %1").arg(release_date)
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: "#646464"
                        font.weight: Font.Light
                        visible: typeof(url) == "string" && url != "" && url != "internal://format"
                        text: !url ? "" :
                                     typeof(extract_sha256) != "undefined" && imageWriter.isCached(url,extract_sha256)
                                     ? qsTr("Cached on your computer")
                                     : url.startsWith("file://")
                                       ? qsTr("Local file")
                                       : qsTr("Online - %1 GB download").arg((image_download_size/1073741824).toFixed(1))
                    }

                    ToolTip {
                        visible: osMouseArea.containsMouse && typeof(tooltip) == "string" && tooltip != ""
                        delay: 1000
                        text: typeof(tooltip) == "string" ? tooltip : ""
                        clip: false
                    }
                }
                Image {
                    source: "icons/ic_chevron_right_40px.svg"
                    visible: (typeof(subitems_json) == "string" && subitems_json != "") || (typeof(subitems_url) == "string" && subitems_url != "" && subitems_url != "internal://back")
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 40
                    fillMode: Image.PreserveAspectFit
                }
            }
        }
    }

    /*
      Popup for storage device selection
     */
    Popup {
        id: dstpopup
        x: 50
        y: 25
        width: parent.width-100
        height: parent.height-50
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: imageWriter.stopDriveListPolling()

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
                    dstpopup.close()
                }
            }
        }

        ColumnLayout {
            spacing: 10

            Text {
                text: qsTr("Storage")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
                Layout.topMargin: 10
                font.family: roboto.name
                font.bold: true
            }

            Item {
                clip: true
                Layout.preferredWidth: dstlist.width
                Layout.preferredHeight: dstlist.height

                ListView {
                    id: dstlist
                    model: driveListModel
                    delegate: dstdelegate
                    width: window.width-100
                    height: window.height-100
                    boundsBehavior: Flickable.StopAtBounds
                    highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
                    ScrollBar.vertical: ScrollBar {
                        width: 10
                        policy: dstlist.contentHeight > dstlist.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    }
                    Keys.onSpacePressed: {
                        if (currentIndex == -1)
                            return
                        selectDstItem(currentItem)
                    }
                    Accessible.onPressAction: {
                        if (currentIndex == -1)
                            return
                        selectDstItem(currentItem)
                    }
                    Keys.onEnterPressed: Keys.onSpacePressed(event)
                    Keys.onReturnPressed: Keys.onSpacePressed(event)
                }

            }
        }
    }

    Component {
        id: dstdelegate
        Item {
            width: window.width-100
            height: 60
            Accessible.name: {
                if (isMaskrom)
                    return description + ". " + qsTr("Detected in MaskROM mode")
                if (isLoader)
                    return description + ". " + qsTr("Detected in Loader mode")
                var txt = description+" - "+(size/1000000000).toFixed(1)+" gigabytes"
                if (mountpoints.length > 0) {
                    txt += qsTr("Mounted as %1").arg(mountpoints.join(", "))
                }
                return txt;
            }
            property string description: model.description
            property string device: model.device
            property string size: model.size
            property bool isMaskrom: typeof(model.isMaskrom) != "undefined" && model.isMaskrom
            property bool isLoader: typeof(model.isLoader) != "undefined" && model.isLoader

            Rectangle {
                id: dstbgrect
                anchors.fill: parent
                color: "#f5f5f5"
                visible: mouseOver && parent.ListView.view.currentIndex !== index
                property bool mouseOver: false

            }

            Rectangle {
                id: dstborderrect
                implicitHeight: 1
                implicitWidth: parent.width
                color: "#dcdcdc"
                y: parent.height
            }

            Row {
                leftPadding: 25

                Column {
                    width: 64

                    Image {
                        source: isUsb ? "icons/ic_usb_40px.svg" : isScsi ? "icons/ic_storage_40px.svg" : "icons/ic_sd_storage_40px.svg"
                        verticalAlignment: Image.AlignVCenter
                        height: parent.parent.parent.height
                        fillMode: Image.Pad
                    }
                }

                Column {
                    width: parent.parent.width-64

                    Text {
                        textFormat: Text.StyledText
                        height: parent.parent.parent.height
                        verticalAlignment: Text.AlignVCenter
                        font.family: roboto.name
                        text: {
                            if (isMaskrom) {
                                return "<p><font size='4'>"+description+"</font></p>" +
                                       "<font color='#28a745'>"+qsTr("Recovery mode (MaskROM) — will load bootloader and flash via Rockchip USB")+"</font>"
                            }
                            if (isLoader) {
                                return "<p><font size='4'>"+description+"</font></p>" +
                                       "<font color='#28a745'>"+qsTr("Loader mode — ready to flash firmware")+"</font>"
                            }
                            var sizeStr = (size/1000000000).toFixed(1)+" GB";
                            var txt;
                            if (isReadOnly) {
                                txt = "<p><font size='4' color='grey'>"+description+" - "+sizeStr+"</font></p>"
                                txt += "<font color='grey'>"
                                if (mountpoints.length > 0) {
                                    txt += qsTr("Mounted as %1").arg(mountpoints.join(", "))+" "
                                }
                                txt += qsTr("[WRITE PROTECTED]")+"</font>"
                            } else {
                                txt = "<p><font size='4'>"+description+" - "+sizeStr+"</font></p>"
                                if (mountpoints.length > 0) {
                                    txt += "<font color='grey'>"+qsTr("Mounted as %1").arg(mountpoints.join(", "))+"</font>"
                                }
                            }
                            return txt;
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onEntered: {
                    dstbgrect.mouseOver = true
                }

                onExited: {
                    dstbgrect.mouseOver = false
                }

                onClicked: {
                    selectDstItem(model)
                }
            }
        }
    }


    MsgPopup {
        id: msgpopup
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
        id: confirmwritepopup
        continueButton: false
        yesButton: true
        noButton: true
        title: qsTr("Warning")
        onYes: {
            langbar.visible = false
            writebutton.enabled = false
            cancelwritebutton.enabled = true
            cancelwritebutton.visible = true
            cancelverifybutton.enabled = true
            resetDownloadTracking()
            progressText.text = qsTr("Preparing to write...");
            progressText.visible = true
            progressBar.visible = true
            progressBar.indeterminate = true
            progressBar.Material.accent = "#ffffff"
            osbutton.enabled = false
            dstbutton.enabled = false
            imageWriter.setVerifyEnabled(true)
            imageWriter.startWrite()
        }

        function askForConfirmation()
        {
            var isRockusb = (imageWriter.dst().indexOf("rockusb:") === 0);
            if (imageWriter.isOhdFile(imageWriter.src())) {
                if (isRockusb) {
                    text = qsTr("The update (.ohd) will be flashed directly to the board over Rockchip USB.<br><br>Are you sure you want to continue?")
                } else {
                    text = qsTr("The update package (.ohd) will be copied to the FAT32 partition on <b>%1</b>.<br><br>Are you sure you want to continue?").arg(dstbutton.text)
                }
                openPopup()
                return
            }
            var bootType=imageWriter.getValue("bootType");
            if(bootType==="Ground"){
            text = qsTr("All existing data on <b>%1</b> will be erased.<br><b>This Device will boot as Groundstation!</b><br>Are you sure you want to continue?").arg(dstbutton.text)
            openPopup()
            }
            else if(bootType==="Air"){
            text = qsTr("All existing data on <b>%1</b> will be erased.<br><b>This Device will boot as Air!</b><br>Are you sure you want to continue?").arg(dstbutton.text)
            openPopup()
            }
            else{
            text = qsTr("All existing data on <b>%1</b> will be erased.<br><br>Are you sure you want to continue?").arg(dstbutton.text)
            openPopup()
            }
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

    OptionsPopup {
        id: optionspopup
    }

    UseSavedSettingsPopup {
        id: usesavedsettingspopup
        onYes: {
            optionspopup.initialize()
            optionspopup.applySettings()
            confirmwritepopup.askForConfirmation()
        }
        onNo: {
            imageWriter.clearSavedCustomizationSettings()
            confirmwritepopup.askForConfirmation()
        }
        onEditSettings: {
            optionspopup.openPopup()
        }
    }

    function resetDownloadTracking() {
        downloadSpeedMB = 0
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
            downloadSpeedMB = 0
            return
        }

        var elapsedSeconds = (nowMs - lastDownloadTimestamp) / 1000
        if (elapsedSeconds > 0 && currentBytes >= lastDownloadBytes) {
            var bytesPerSecond = (currentBytes - lastDownloadBytes) / elapsedSeconds
            downloadSpeedMB = bytesPerSecond / (1024 * 1024)
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
    function httpRequest(url, callback) {
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
            progressText.text = qsTr("Writing... %1% (%2 MB/s)").arg(Math.floor(newPos*100)).arg(downloadSpeedMB.toFixed(1))
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
        imageWriter.setSetting("premiumCertificatePath", "")
    }

    function resetWorkflowAfterSuccess() {
        resetOpenHdSettingsForNewImage()
        optionspopup.initialized = false
        imageWriter.setSrc("")
        imageWriter.setDst("")
        osbutton.text = qsTr("CHOOSE OS")
        dstbutton.text = qsTr("CHOOSE STORAGE")
    }

    function onError(msg) {
        msgpopup.title = qsTr("Error")
        msgpopup.text = msg
        msgpopup.openPopup()
        resetWriteButton()
    }

    function onSuccess() {
        if (imageWriter.isOhdFile(imageWriter.src())) {
            var isRockusb = (imageWriter.dst().indexOf("rockusb:") === 0);
            msgpopup.title = qsTr("Update complete!")
            if (isRockusb) {
                msgpopup.text = qsTr("<b>%1</b> was flashed to the board.<br>The board is now rebooting.").arg(osbutton.text)
            } else {
                msgpopup.text = qsTr("<b>%1</b> was copied to the FAT32 partition on <b>%2</b>.<br>You can now safely remove the card and insert it into your board.").arg(osbutton.text).arg(dstbutton.text)
            }
            msgpopup.continueButton = false
            msgpopup.detailsButton = false
            msgpopup.openPopup()
            resetWorkflowAfterSuccess()
            resetWriteButton()
            return
        }

        msgpopup.title = qsTr("Image was written successfully!")
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

    function onFileSelected(file) {
        var normalized = file
        if (typeof file === "string") {
            if (file.indexOf("file:") !== 0) {
                normalized = "file:///" + file.replace(/\\/g, "/")
            }
        }
        imageWriter.setSrc(normalized)
        osbutton.text = imageWriter.srcFileName()
        ospopup.close()
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

    function fetchOSlist() {
        httpRequest(imageWriter.constantOsListUrl(), function (x) {
            var o = JSON.parse(x.responseText)
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
        })
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
            ospopup.categorySelected = d.name
        } else if (typeof(d.subitems_url) == "string" && d.subitems_url !== "") {
            if (d.subitems_url === "internal://back")
            {
                osswipeview.decrementCurrentIndex()
                ospopup.categorySelected = ""
            }
            else
            {
                ospopup.categorySelected = d.name
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
                })

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
            imageWriter.setSrc(d.url, d.image_download_size, d.extract_size, typeof(d.extract_sha256) != "undefined" ? d.extract_sha256 : "", typeof(d.contains_multiple_files) != "undefined" ? d.contains_multiple_files : false, ospopup.categorySelected, d.name, typeof(d.init_format) != "undefined" ? d.init_format : "")
            osbutton.text = d.name
            ospopup.close()
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

        dstpopup.close()
        imageWriter.setDst(d.device, d.size)
        dstbutton.text = d.description
        if (imageWriter.readyToWrite()) {
            writebutton.enabled = true
        }
    }
}
