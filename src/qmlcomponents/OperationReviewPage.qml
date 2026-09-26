import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

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
    readonly property bool narrow: width < 720
    readonly property bool shortWindow: height < 520

    signal confirmed()
    signal backRequested()
    signal changeSourceRequested()
    signal changeTargetRequested()
    signal configureRequested()

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
            anchors.horizontalCenter: parent.horizontalCenter
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
                            text: root.configurationComplete
                                  ? qsTr("Configuration saved. Select to review or change it.")
                                  : qsTr("Device role, cameras, display, networking and files")
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

                Item {
                    Layout.fillWidth: true
                    visible: !root.configurationRequired || root.configurationComplete
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
}
