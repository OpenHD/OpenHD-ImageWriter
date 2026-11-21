import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

Dialog {
    id: dialog
    objectName: "partitionPlanDialog"
    property var plan: ({ "ok": true, "text": "", "partitions": [] })
    property string sourceName: ""
    property string targetName: ""
    property var mainWindow: null
    property bool automaticPartitioning: true
    property double maximumRecordingsMiB: plan.recordingsMaxBytes
        ? Math.floor(Number(plan.recordingsMaxBytes) / (1024 * 1024)) : 0
    property double selectedRecordingsMiB: maximumRecordingsMiB
    readonly property bool canAdjust: plan.ok === true && plan.recordingsEditable === true && maximumRecordingsMiB >= 64
    readonly property double selectedRecordingsBytes: automaticPartitioning
        ? 0 : Math.floor(selectedRecordingsMiB) * 1024 * 1024
    signal yes()

    function openPopup() { open() }
    function sizeText(bytes) {
        var gib = Number(bytes) / (1024 * 1024 * 1024)
        if (gib >= 1) return gib.toFixed(2) + " GiB"
        return (Number(bytes) / (1024 * 1024)).toFixed(0) + " MiB"
    }
    function rowSize(row) {
        if (row.recordings && !automaticPartitioning)
            return selectedRecordingsMiB * 1024 * 1024
        return Number(row.sizeBytes || 0)
    }
    function allocatedBytes() {
        var total = 0
        var rows = plan.partitions || []
        for (var i = 0; i < rows.length; ++i) total += rowSize(rows[i])
        return total
    }
    function freeBytes() {
        return Math.max(0, Number(plan.diskBytes || 0) - allocatedBytes())
    }

    parent: dialog.mainWindow ? dialog.mainWindow.Overlay.overlay : Overlay.overlay
    x: 0
    y: 0
    // Bind to the top-level window explicitly. Popup's implicit sizing can
    // otherwise follow the flash page (which starts to the right of the app
    // sidebar) and leave that part of the application uncovered.
    width: mainWindow ? mainWindow.width : parent.width
    height: mainWindow ? mainWindow.height : parent.height
    modal: true
    title: qsTr("Review partition layout")
    standardButtons: plan.ok ? Dialog.Ok | Dialog.Cancel : Dialog.Close
    Material.theme: Material.Dark
    Material.background: "#102633"
    Material.foreground: "#e5edf2"
    onOpened: {
        partitionReviewScroll.contentY = 0
        automaticPartitioning = true
        selectedRecordingsMiB = maximumRecordingsMiB
        if (standardButton(Dialog.Ok)) standardButton(Dialog.Ok).text = qsTr("Erase and write")
    }
    onAccepted: if (plan.ok) yes()

    contentItem: Flickable {
        id: partitionReviewScroll
        objectName: "partitionReviewScroll"
        clip: true
        contentWidth: width
        contentHeight: reviewContents.height
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            id: reviewScrollBar
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
        id: reviewContents
        width: Math.max(0, partitionReviewScroll.width - reviewScrollBar.width)
        height: implicitHeight
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: warningLabel.implicitHeight + 24
            Layout.minimumHeight: 60
            radius: 8
            color: "#3b2025"
            border.color: "#e56868"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                Label { text: "⚠"; color: "#ffb35c"; font.pixelSize: 24 }
                Label {
                    id: warningLabel
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    text: qsTr("All data on %1 will be erased. Image: %2")
                        .arg(dialog.targetName).arg(dialog.sourceName)
                    font.bold: true
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("Partition layout")
            font.pixelSize: 19
            font.bold: true
            color: "#eef6f9"
        }

        Rectangle {
            id: diskBar
            objectName: "partitionBar"
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            radius: 7
            color: "#263b46"
            border.color: "#6b7f89"
            clip: true
            Row {
                anchors.fill: parent
                Repeater {
                    model: dialog.plan.partitions || []
                    Rectangle {
                        width: (dialog.rowSize(modelData) / Math.max(1, Number(dialog.plan.diskBytes || 1))) * diskBar.width
                        height: diskBar.height
                        color: modelData.recordings ? "#e98d36"
                            : (modelData.filesystem === "FAT" ? "#2979bd"
                                : (modelData.filesystem === "FAT32" ? "#28a38b" : "#8a55a5"))
                        border.color: "#102633"
                    }
                }
                Rectangle {
                    width: Math.max(0, diskBar.width - dialog.allocatedBytes() /
                        Math.max(1, Number(dialog.plan.diskBytes || 1)) * diskBar.width)
                    height: diskBar.height
                    color: "#dce4e8"
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            width: parent.width
            spacing: 14
            Repeater {
                model: dialog.plan.partitions || []
                RowLayout {
                    width: implicitWidth
                    spacing: 5
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: modelData.recordings ? "#e98d36"
                            : (modelData.filesystem === "FAT" ? "#2979bd"
                                : (modelData.filesystem === "FAT32" ? "#28a38b" : "#8a55a5"))
                    }
                    Label {
                        text: modelData.name + " · " + dialog.sizeText(dialog.rowSize(modelData))
                        color: "#c7d4db"
                        font.pixelSize: 11
                    }
                }
            }
            RowLayout {
                width: implicitWidth
                spacing: 5
                Rectangle { width: 10; height: 10; radius: 5; color: "#dce4e8" }
                Label { text: qsTr("Free space · %1").arg(dialog.sizeText(dialog.freeBytes())); color: "#c7d4db"; font.pixelSize: 11 }
            }
        }

        Rectangle {
            objectName: "partitionTable"
            Layout.fillWidth: true
            Layout.preferredHeight: 38 + (planText.visible ? planText.implicitHeight + 24
                                                          : (dialog.plan.partitions || []).length * 52)
            Layout.minimumHeight: Layout.preferredHeight
            radius: 8
            color: "#132d3a"
            border.color: "#355362"
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: "#1b3a49"
            RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        Label { Layout.fillWidth: true; Layout.preferredWidth: parent.width * 0.27; text: qsTr("Device / partition"); color: "#aebfc8"; elide: Text.ElideRight }
                        Label { Layout.fillWidth: true; Layout.preferredWidth: parent.width * 0.15; text: qsTr("Type"); color: "#aebfc8"; elide: Text.ElideRight }
                        Label { Layout.fillWidth: true; Layout.preferredWidth: parent.width * 0.17; text: qsTr("Mount point"); color: "#aebfc8"; elide: Text.ElideRight }
                        Label { Layout.fillWidth: true; Layout.preferredWidth: parent.width * 0.25; text: qsTr("Action"); color: "#aebfc8"; elide: Text.ElideRight }
                        Label { Layout.preferredWidth: parent.width * 0.12; horizontalAlignment: Text.AlignRight; text: qsTr("Size"); color: "#aebfc8" }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    Repeater {
                        model: dialog.plan.partitions || []
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            color: modelData.recordings ? "#173e43" : "transparent"
                            border.color: "#28424e"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                Label {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: parent.width * 0.27
                                    text: "mmcblk0p" + modelData.number + "  ·  " + modelData.name
                                    color: "#e5edf2"
                                    elide: Text.ElideRight
                                }
                                Label { Layout.fillWidth: true; Layout.preferredWidth: parent.width * 0.15; text: modelData.filesystem; color: "#c1cfd5"; elide: Text.ElideRight }
                                Label { Layout.fillWidth: true; Layout.preferredWidth: parent.width * 0.17; text: modelData.mountPoint || "—"; color: "#c1cfd5"; elide: Text.ElideRight }
                                Label {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: parent.width * 0.25
                                    text: modelData.action
                                    color: modelData.recordings ? "#83d6bf" : "#aebfc8"
                                    elide: Text.ElideRight
                                }
                                Label {
                                    Layout.preferredWidth: parent.width * 0.12
                                    horizontalAlignment: Text.AlignRight
                                    text: dialog.sizeText(dialog.rowSize(modelData))
                                    color: "#eef6f9"
                                    font.bold: modelData.recordings
                                }
                            }
                        }
                    }
                    Label {
                        id: planText
                        objectName: "partitionPlanText"
                        Layout.fillWidth: true
                        Layout.margins: 12
                        visible: !(dialog.plan.partitions && dialog.plan.partitions.length)
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        text: dialog.plan.text || ""
                        color: "#d0dce1"
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label { text: qsTr("Recordings storage"); font.bold: true; color: "#eef6f9" }
            RadioButton {
                objectName: "automaticPartitioning"
                text: qsTr("Automatic (recommended)")
                checked: dialog.automaticPartitioning
                onClicked: dialog.automaticPartitioning = true
            }
            RadioButton {
                objectName: "manualPartitioning"
                text: qsTr("Adjust size")
                enabled: dialog.canAdjust
                checked: !dialog.automaticPartitioning
                onClicked: dialog.automaticPartitioning = false
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: dialog.canAdjust && !dialog.automaticPartitioning
            Label { text: qsTr("RECORDINGS size"); color: "#c7d4db" }
            Slider {
                id: recordingSizeSlider
                objectName: "recordingsSizeSlider"
                Layout.fillWidth: true
                from: 64
                to: Math.max(64, dialog.maximumRecordingsMiB)
                stepSize: 64
                snapMode: Slider.SnapAlways
                value: dialog.selectedRecordingsMiB
                onMoved: dialog.selectedRecordingsMiB = Math.min(dialog.maximumRecordingsMiB,
                    Math.max(64, Math.floor(value / 64) * 64))
            }
            Label {
                Layout.preferredWidth: 100
                horizontalAlignment: Text.AlignRight
                text: dialog.sizeText(dialog.selectedRecordingsMiB * 1024 * 1024)
                color: "#eef6f9"
            }
        }

        Label {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            visible: dialog.plan.ok
            text: dialog.canAdjust
                ? qsTr("Image partitions stay as supplied. Adjusting RECORDINGS leaves the remaining capacity unallocated.")
                : qsTr("ImageWriter prepares and verifies the shown layout before reporting success.")
            color: "#a9bac5"
        }
        }
    }
}
