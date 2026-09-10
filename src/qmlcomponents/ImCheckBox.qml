/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2022 Raspberry Pi Ltd
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import QtQuick.Controls.Material 2.2

CheckBox {
    font.family: roboto.name
    font.pixelSize: 13
    Material.foreground: "#e7f0f5"
    Keys.onEnterPressed: toggle()
    Keys.onReturnPressed: toggle()
    Material.accent: "#168df3"
}
