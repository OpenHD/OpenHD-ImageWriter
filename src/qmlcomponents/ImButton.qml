/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2022 Raspberry Pi Ltd
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Button {
    font.family: roboto.name
    Material.background: activeFocus ? "#ffffff" : "#ffffff"
    Material.foreground: "#2C3E50"
    Material.roundedScale: Material.ExtraSmallScale
    Accessible.onPressAction: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onReturnPressed: clicked()
}
