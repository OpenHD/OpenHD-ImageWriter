import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import "FleetProfilesHelper.js" as FleetProfilesHelper

Item {
    id: root

    property string title: qsTr("Review operation")
    property string subtitle: qsTr("Confirm the source and target before continuing.")
    property string sourceName: ""
    property string sourceDetail: ""
    property string targetName: ""
    property string targetDetail: ""
    property string confirmText: qsTr("Start")
    property bool updateOperation: false
    property bool configurationRequired: false
    property bool configurationComplete: false
    property bool fleetControlSignedIn: false
    property string profileName: ""
    property string profileDetail: ""
    property string profileIcon: ""
    property bool useProfileSettings: profileName.length > 0
    readonly property bool narrow: width < 720
    readonly property bool shortWindow: height < 520

    signal confirmed()
    signal backRequested()
    signal changeSourceRequested()
    signal changeTargetRequested()
    signal configureRequested()
    signal profileSettingsToggled(bool enabled)
    signal profileSelected(var profile)
    signal clearProfileRequested()

    focus: visible
    Keys.onEscapePressed: backRequested()

    Flickable {
        id: reviewScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: reviewContent.implicitHeight + 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: reviewContent
            width: Math.min(reviewScroll.width - (root.narrow ? 24 : 48), 780)
            x: Math.max(0, Math.round((reviewScroll.width - width) / 2))
            y: 14
            spacing: root.narrow ? 8 : 11

            RowLayout {
                Layout.fillWidth: true
                spacing: root.narrow ? 8 : 12

                Image {
                    Layout.preferredWidth: root.narrow ? 38 : 46
                    Layout.preferredHeight: root.narrow ? 38 : 46
                    source: "../icons/ui/review-write.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 256
                    sourceSize.height: 256
                }

                PageHeader {
                    Layout.fillWidth: true
                    title: root.title
                    subtitle: root.subtitle
                }

                PageBackButton {
                    compact: root.narrow
                    onClicked: root.backRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.narrow ? 78 : 88
                radius: 8
                color: "#0e2734"
                border.width: 1
                border.color: "#20556e"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: root.narrow ? 10 : 14
                    spacing: root.narrow ? 9 : 13

                    Image {
                        Layout.preferredWidth: root.narrow ? 38 : 46
                        Layout.preferredHeight: root.narrow ? 38 : 46
                        source: root.updateOperation ? "../icons/ui/update.svg" : "../icons/ui/image-file.svg"
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.sourceName
                            color: "#f3f7fa"
                            font.pixelSize: root.narrow ? 15 : 17
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.updateOperation ? qsTr("Update package") : qsTr("Source image")
                            color: "#91b7cc"
                            font.pixelSize: 11
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: root.sourceDetail
                            color: "#7fa4b8"
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                        }
                    }

                    ModernActionButton {
                        Layout.preferredWidth: root.narrow ? 86 : 126
                        text: root.narrow
                              ? qsTr("Change")
                              : (root.updateOperation ? qsTr("Change update") : qsTr("Change image"))
                        onClicked: root.changeSourceRequested()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.narrow ? 74 : 82
                radius: 8
                color: "#0e2734"
                border.width: 1
                border.color: "#20556e"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: root.narrow ? 10 : 14
                    spacing: root.narrow ? 9 : 13

                    Image {
                        Layout.preferredWidth: root.narrow ? 38 : 44
                        Layout.preferredHeight: root.narrow ? 38 : 44
                        source: "../icons/ui/storage-card.svg"
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.targetName
                            color: "#f3f7fa"
                            font.pixelSize: root.narrow ? 15 : 17
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: qsTr("Destination device")
                            color: "#91b7cc"
                            font.pixelSize: 11
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: root.targetDetail
                            color: "#7fa4b8"
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                        }
                    }

                    ModernActionButton {
                        Layout.preferredWidth: root.narrow ? 86 : 126
                        text: root.narrow ? qsTr("Change") : qsTr("Change device")
                        onClicked: root.changeTargetRequested()
                    }
                }
            }

            Rectangle {
                id: profileCard
                visible: !root.updateOperation && root.fleetControlSignedIn
                Layout.fillWidth: true
                Layout.preferredHeight: root.narrow ? 80 : 88
                radius: 8
                readonly property bool hasProfile: root.profileName.length > 0
                readonly property bool isActive: hasProfile && root.useProfileSettings
                color: isActive ? "#0e3146" : "#0e2734"
                border.width: isActive ? 2 : 1
                border.color: isActive ? "#00a6f2" : "#20556e"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !profileCard.isActive
                    onClicked: profilePickerPopup.openPicker()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: root.narrow ? 10 : 14
                    spacing: root.narrow ? 9 : 13

                    Image {
                        Layout.preferredWidth: root.narrow ? 38 : 46
                        Layout.preferredHeight: root.narrow ? 38 : 46
                        source: (root.profileIcon && root.profileIcon.length > 0)
                                ? FleetProfilesHelper.iconSource(root.profileIcon)
                                : "../icons/ui/hub.svg"
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: profileCard.hasProfile
                                  ? qsTr("use your profiles setting: %1").arg(root.profileName)
                                  : qsTr("use your profiles setting")
                            color: "#f3f7fa"
                            font.pixelSize: root.narrow ? 15 : 17
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (profileCard.isActive) {
                                    return root.profileDetail.length > 0
                                        ? root.profileDetail
                                        : qsTr("Active: preconfigured role, hardware, camera, display and networking.")
                                }
                                if (profileCard.hasProfile) {
                                    return qsTr("Inactive: toggle on to apply settings from '%1'.").arg(root.profileName)
                                }
                                return qsTr("Select a FleetControl craft or preset to preconfigure write options.")
                            }
                            color: profileCard.isActive ? "#4dc5f8" : "#89aebb"
                            font.pixelSize: root.narrow ? 10 : 11
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        spacing: root.narrow ? 6 : 8

                        ModernActionButton {
                            visible: profileCard.hasProfile
                            Layout.preferredWidth: root.narrow ? 68 : 82
                            implicitHeight: root.narrow ? 32 : 36
                            text: qsTr("Change")
                            onClicked: profilePickerPopup.openPicker()
                        }

                        Switch {
                            id: profileSwitch
                            visible: profileCard.hasProfile
                            checked: root.useProfileSettings
                            onToggled: {
                                root.useProfileSettings = checked
                                root.profileSettingsToggled(checked)
                            }
                        }

                        ModernActionButton {
                            visible: !profileCard.hasProfile
                            Layout.preferredWidth: root.narrow ? 116 : 142
                            implicitHeight: root.narrow ? 34 : 38
                            primary: true
                            text: qsTr("Select profile \u25be")
                            onClicked: profilePickerPopup.openPicker()
                        }
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: root.narrow ? 78 : 88
                visible: root.configurationRequired
                hoverEnabled: true
                onClicked: root.configureRequested()

                background: Rectangle {
                    radius: 8
                    color: parent.down ? "#075f9d" : parent.hovered ? "#0879c7" : "#076caf"
                    border.width: 1
                    border.color: root.configurationComplete ? "#41c98a" : "#159ae9"
                }

                contentItem: RowLayout {
                    spacing: root.narrow ? 10 : 14

                    Image {
                        Layout.leftMargin: root.narrow ? 6 : 12
                        Layout.preferredWidth: root.narrow ? 40 : 48
                        Layout.preferredHeight: root.narrow ? 40 : 48
                        source: "../icons/ui/configure-write.svg"
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Configure write options")
                            color: "white"
                            font.pixelSize: root.narrow ? 16 : 18
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (root.fleetControlSignedIn && root.useProfileSettings && root.profileName.length > 0)
                                    return qsTr("Pre-configured from '%1'. Select to review or adjust.").arg(root.profileName)
                                if (root.configurationComplete)
                                    return qsTr("Configuration saved. Select to review or change it.")
                                return qsTr("Device role, cameras, display, networking and files")
                            }
                            color: "#c1e2f5"
                            font.pixelSize: root.narrow ? 10 : 11
                            wrapMode: Text.WordWrap
                        }
                    }

                    Text {
                        Layout.rightMargin: root.narrow ? 6 : 12
                        text: root.configurationComplete ? "\u2713" : "\u203a"
                        color: "white"
                        font.pixelSize: root.configurationComplete ? 20 : 28
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    visible: root.configurationRequired && !root.configurationComplete
                    text: qsTr("Configure and save the write options before continuing.")
                    color: "#f2d77f"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.fleetControlSignedIn && root.useProfileSettings && root.profileName.length > 0
                    text: qsTr("Using profile '%1'. Ready to write.").arg(root.profileName)
                    color: "#41c98a"
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillWidth: true
                    visible: !root.configurationRequired || (root.configurationComplete && !(root.fleetControlSignedIn && root.useProfileSettings && root.profileName.length > 0))
                }

                ModernActionButton {
                    text: root.confirmText
                    primary: true
                    enabled: !root.configurationRequired || root.configurationComplete
                    onClicked: root.confirmed()
                }
            }
        }
    }

    Popup {
        id: profilePickerPopup
        modal: true
        focus: true
        dim: true
        width: Math.min(root.width - (root.narrow ? 20 : 40), 620)
        padding: 16
        height: Math.min(pickerColumn.implicitHeight + 32, root.height - 30)
        x: Math.round((root.width - width) / 2)
        y: Math.max(12, Math.round((root.height - height) / 2))
        clip: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var profilesList: []

        function openPicker() {
            profilesList = FleetProfilesHelper.loadProfiles(imageWriter)
            open()
        }

        background: Rectangle {
            radius: 10
            color: "#0c1d29"
            border.width: 1
            border.color: "#00a6f2"
        }

        contentItem: ColumnLayout {
            id: pickerColumn
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Image {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    source: "../icons/ui/fleetcontrol.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Select Fleet Profile")
                    color: "#ffffff"
                    font.pixelSize: root.narrow ? 15 : 17
                    font.bold: true
                    elide: Text.ElideRight
                }

                ToolButton {
                    text: "\u2715"
                    font.pixelSize: 16
                    onClicked: profilePickerPopup.close()
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Choose a craft from your fleet or a preset to automatically preconfigure write options:")
                color: "#89aebb"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#1c3c50"
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(profileListView.implicitHeight, 260)
                contentWidth: width
                contentHeight: profileListView.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: profileListView
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: profilePickerPopup.profilesList

                        Rectangle {
                            id: itemCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 6
                            readonly property bool isSelected: modelData.craftName === root.profileName && root.useProfileSettings
                            readonly property bool isHovered: itemMouse.containsMouse
                            color: isSelected ? "#0e354c" : isHovered ? "#143347" : "#0d2230"
                            border.width: isSelected ? 2 : 1
                            border.color: isSelected ? "#00a6f2" : isHovered ? "#295b77" : "#1a3b50"

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    FleetProfilesHelper.applyProfile(imageWriter, modelData)
                                    root.profileName = modelData.craftName
                                    root.profileIcon = modelData.craftIcon || ""
                                    root.profileDetail = FleetProfilesHelper.profileSummary(modelData)
                                    root.useProfileSettings = true
                                    root.configurationComplete = true
                                    root.profileSelected(modelData)
                                    profilePickerPopup.close()
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 10

                                Image {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    source: FleetProfilesHelper.iconSource(modelData.craftIcon)
                                    fillMode: Image.PreserveAspectFit
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: modelData.craftName
                                            color: "#ffffff"
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            readonly property bool isGround: (modelData.craftRole || (modelData.craftCategory === "station" ? "ground" : "air")) === "ground"
                                            Layout.preferredHeight: 16
                                            Layout.preferredWidth: roleLabel.implicitWidth + 8
                                            radius: 3
                                            color: isGround ? "#3d2a08" : "#08374d"
                                            border.width: 1
                                            border.color: isGround ? "#d98818" : "#00a6f2"

                                            Text {
                                                id: roleLabel
                                                anchors.centerIn: parent
                                                text: parent.isGround ? qsTr("GROUND") : qsTr("AIR")
                                                color: parent.isGround ? "#fcd07a" : "#4dc5f8"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }

                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: FleetProfilesHelper.profileSummary(modelData)
                                        color: "#8fb4c8"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    visible: itemCard.isSelected
                                    text: "\u2713"
                                    color: "#41c98a"
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#1c3c50"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ToolButton {
                    text: qsTr("Clear profile (Manual configuration)")
                    font.pixelSize: 11
                    onClicked: {
                        root.profileName = ""
                        root.profileDetail = ""
                        root.profileIcon = ""
                        root.useProfileSettings = false
                        root.clearProfileRequested()
                        profilePickerPopup.close()
                    }
                }

                Item { Layout.fillWidth: true }

                ModernActionButton {
                    text: qsTr("Cancel")
                    onClicked: profilePickerPopup.close()
                }
            }
        }
    }
}
