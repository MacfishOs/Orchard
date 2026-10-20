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

// One option inside SettingsSegmented. entry: { value, label, enabled?, tip?, name? }
AbstractButton {
    id: seg

    property var entry: ({ value: "a", label: "Option" })
    property bool selected: false

    leftPadding: 14
    rightPadding: 14
    hoverEnabled: true
    enabled: entry.enabled !== false
    opacity: enabled ? 1 : 0.45
    text: entry.label
    Accessible.name: entry.name || entry.label
    // Disabled segments explain themselves on hover.
    ToolTip.visible: hovered && !enabled && !!entry.tip
    ToolTip.text: entry.tip || ""

    contentItem: Text {
        text: seg.text
        color: seg.selected ? OrchardAppearance.onAccent : "#d6d9d5"
        Behavior on color { ColorAnimation { duration: Motion.normal } }
        font.family: "Inter"
        font.pixelSize: 13
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 4
        color: !seg.selected && seg.hovered ? "#12ffffff" : "transparent"
        border.color: seg.visualFocus ? OrchardAppearance.accentStrong : "transparent"
        border.width: 2
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }
}
