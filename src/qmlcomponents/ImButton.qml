/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2022 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2

Button {
    id: control

    font.family: roboto.name
    font.pixelSize: 13
    font.bold: true
    hoverEnabled: true
    leftPadding: 16
    rightPadding: 16
    topPadding: 9
    bottomPadding: 9

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? "#f5f9fc" : "#708491"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitHeight: 40
        radius: 6
        color: !control.enabled ? "#172a35"
              : control.down ? "#0064bd"
              : control.hovered || control.activeFocus ? "#168df3"
              : "#0878da"
        border.color: control.activeFocus ? "#8bc8ff" : (control.enabled ? "#2698f5" : "#29404d")
        border.width: 1

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Accessible.onPressAction: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onReturnPressed: clicked()
}
