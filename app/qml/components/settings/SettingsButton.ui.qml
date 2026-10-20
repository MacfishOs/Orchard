/*
 * Copyright (C) 2026 SFG545
 *
 * This file is part of Orchard.
 *
 * Orchard is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Orchard is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

import Orchard
import QtQuick
import QtQuick.Controls

Button {
    id: control
    implicitHeight: 32
    leftPadding: 14
    rightPadding: 14
    topPadding: 0
    bottomPadding: 0
    font.family: "Inter"
    font.pixelSize: 13
    hoverEnabled: true
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.highlighted ? OrchardAppearance.onAccent : "#f0eee7"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 5
        opacity: control.enabled ? 1 : 0.5
        color: control.highlighted
               ? (control.down ? Qt.darker(OrchardAppearance.accent, 1.12) : control.hovered ? Qt.lighter(OrchardAppearance.accent, 1.08) : OrchardAppearance.accent)
               : control.down ? "#0affffff" : control.hovered ? "#18ffffff" : "#10ffffff"
        border.color: control.visualFocus ? OrchardAppearance.accentStrong : control.highlighted ? "transparent" : "#14ffffff"
        border.width: control.visualFocus ? 2 : 1
        scale: control.down ? 0.97 : 1
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.enter } }
    }
}
