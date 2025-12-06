/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Window 2.2
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2

ApplicationWindow {
    id: configureWindow
    visible: true
    color: "#34495E"

    width: imageWriter.isEmbeddedMode() ? -1 : 680
    height: imageWriter.isEmbeddedMode() ? -1 : 420
    minimumWidth: imageWriter.isEmbeddedMode() ? -1 : 680
    minimumHeight: imageWriter.isEmbeddedMode() ? -1 : 420

    title: qsTr("Configure - OpenHD ImageWriter v%1").arg(imageWriter.constantVersion())

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Label {
            text: qsTr("Configuration placeholder")
            color: "white"
            font.pixelSize: 20
        }

        Label {
            text: qsTr("Build your configuration UI here.")
            color: "white"
            wrapMode: Text.WordWrap
        }

        Button {
            text: qsTr("Back")
            onClicked: configureWindow.close()
        }
    }
}
