/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2022 Raspberry Pi Ltd
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

RadioButton {
    Keys.onEnterPressed: toggle()
    Keys.onReturnPressed: toggle()
}
