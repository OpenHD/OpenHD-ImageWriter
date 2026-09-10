import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

Item {
    id: root

    property var sourceModel: null
    property bool rootLevel: true
    property string categoryName: ""
    property string pageTitle: qsTr("Choose an image")
    property string pageSubtitle: qsTr("Select the device or image you want to write.")
    property string nestedSubtitle: qsTr("Choose the OpenHD release to use for this device.")
    property string userDefinedTitle: qsTr("User defined")
    property string formatTitle: qsTr("Erase / Format")
    readonly property bool narrow: width < 720
    readonly property int sourceCount: sourceModel ? sourceModel.count : 0
    readonly property int itemOffset: rootLevel ? 0 : 1
    readonly property int mainItemCount: Math.max(0, sourceCount - (rootLevel ? 2 : 1))

    signal itemSelected(var item)
    signal closeRequested()

    focus: visible
    onVisibleChanged: {
        if (visible)
            forceActiveFocus()
    }

    function itemAt(displayIndex) {
        return sourceModel ? sourceModel.get(displayIndex + itemOffset) : null
    }

    function utilityAt(offsetFromEnd) {
        return sourceModel ? sourceModel.get(sourceCount - offsetFromEnd) : null
    }

    function goBack() {
        if (rootLevel) {
            closeRequested()
        } else if (sourceModel && sourceModel.count > 0) {
            itemSelected(sourceModel.get(0))
        }
    }

    Keys.onEscapePressed: goBack()

    Flickable {
        id: pageScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: pageContent.implicitHeight + (root.narrow ? 40 : 70)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: pageContent
            width: Math.min(pageScroll.width - (root.narrow ? 36 : 72), 1150)
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.narrow ? 24 : 30
            spacing: 20

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                PageHeader {
                    Layout.fillWidth: true
                    title: root.rootLevel || root.categoryName.length === 0
                           ? root.pageTitle
                           : root.categoryName
                    subtitle: root.rootLevel
                              ? root.pageSubtitle
                              : root.nestedSubtitle
                }

                Button {
                    text: root.rootLevel ? qsTr("Back to setup") : qsTr("Back")
                    flat: true
                    onClicked: root.goBack()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.mainItemCount

                    SelectionRow {
                        property var entry: root.itemAt(index)
                        Layout.fillWidth: true
                        compact: root.narrow
                        title: entry ? entry.name : ""
                        description: entry ? entry.description : ""
                        iconSource: root.resolveIcon(entry ? entry.icon : "")
                        onClicked: {
                            if (entry)
                                root.itemSelected(entry)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 108
                    visible: root.mainItemCount === 0
                    radius: 8
                    color: "#0e2532"
                    border.color: "#294754"

                    Row {
                        anchors.centerIn: parent
                        spacing: 12

                        BusyIndicator {
                            width: 28
                            height: 28
                            running: parent.parent.visible
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Loading available images...")
                            color: "#9fb3bf"
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 2
                visible: root.rootLevel
                color: "#294754"
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.rootLevel && root.sourceCount >= 2
                columns: width >= 680 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                SelectionRow {
                    property var entry: root.utilityAt(1)
                    Layout.fillWidth: true
                    compact: true
                    title: entry ? root.userDefinedTitle : ""
                    description: entry ? entry.description : ""
                    iconSource: root.resolveIcon(entry ? entry.icon : "")
                    onClicked: {
                        if (entry)
                            root.itemSelected(entry)
                    }
                }

                SelectionRow {
                    property var entry: root.utilityAt(2)
                    Layout.fillWidth: true
                    compact: true
                    title: entry ? root.formatTitle : ""
                    description: entry ? entry.description : ""
                    iconSource: root.resolveIcon(entry ? entry.icon : "")
                    onClicked: {
                        if (entry)
                            root.itemSelected(entry)
                    }
                }
            }
        }
    }

    function resolveIcon(value) {
        if (!value || value.length === 0)
            return "../icons/ui/image.svg"
        if (value.indexOf("qrc:") === 0 || value.indexOf("file:") === 0
                || value.indexOf("http:") === 0 || value.indexOf("https:") === 0)
            return value
        return "../" + value
    }
}
