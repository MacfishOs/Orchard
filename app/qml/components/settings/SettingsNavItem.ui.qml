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

import ".."
import Orchard
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sidebar entry of the settings panel. entry: { key, label, icon }
ItemDelegate {
    id: navItem

    property var entry: ({ key: "general", label: "General", icon: "sliders-horizontal" })
    property bool current: false

    implicitHeight: 38
    leftPadding: 14
    rightPadding: 12
    hoverEnabled: true
    Accessible.name: entry.label

    contentItem: RowLayout {
        spacing: 12

        LucideIcon {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            name: navItem.entry.icon
            color: OrchardAppearance.accent
            scale: navItem.down ? 0.88 : navItem.current ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: Motion.slow; easing.type: Easing.OutBack } }
        }

        Text {
            Layout.fillWidth: true
            text: navItem.entry.label
            color: navItem.current ? "#ffffff" : "#d6d9d5"
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: navItem.current ? Font.Medium : Font.Normal
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    // Hover tint only; the selection fill and its accent bar sit underneath.
    background: Rectangle {
        radius: 6
        color: navItem.current ? "transparent" : navItem.down ? "#0cffffff" : navItem.hovered ? "#0fffffff" : "transparent"
        border.color: navItem.visualFocus ? OrchardAppearance.accentStrong : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
