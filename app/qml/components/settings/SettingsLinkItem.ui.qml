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

// Sidebar launcher that opens another popup.
ItemDelegate {
    id: link

    property string glyph: "book-open"
    property string label: "Docs"
    // Accent dot for unread news, such as replies on a bug report.
    property bool badge: false

    implicitHeight: 38
    leftPadding: 14
    rightPadding: 12
    hoverEnabled: true
    Accessible.name: label

    contentItem: RowLayout {
        spacing: 12

        LucideIcon {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            name: link.glyph
            color: OrchardAppearance.accent
        }

        Text {
            Layout.fillWidth: true
            text: link.label
            color: "#d6d9d5"
            font.family: "Inter"
            font.pixelSize: 14
        }

        Rectangle {
            visible: link.badge
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 4
            color: OrchardAppearance.accent
        }

        LucideIcon {
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            name: "chevron-right"
            color: "#9aa19c"
        }
    }

    background: Rectangle {
        radius: 6
        color: link.down ? "#0cffffff" : link.hovered ? "#0fffffff" : "transparent"
        border.color: link.visualFocus ? OrchardAppearance.accentStrong : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
