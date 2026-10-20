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

import QtQuick
import QtQuick.Layouts

// Caption above one card. Rows (SettingsRow) set rowSpacing and verticalPadding to 0.
Item {
    id: root
    property string title
    property int rowSpacing: 20
    property int verticalPadding: 22
    default property alias settings: body.data
    property alias slide: slide
    property alias entrance: entrance
    implicitHeight: panel.y + panel.height
    transform: Translate { id: slide; y: 0 }

    SequentialAnimation {
        id: entrance
        property int delay: 0
        PauseAnimation { duration: entrance.delay }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: slide; property: "y"; to: 0; duration: 420; easing.type: Easing.OutQuint }
        }
    }

    // Wrapper owns the height; setting height on the Text itself loops with its implicit height.
    Item {
        id: heading
        width: parent.width
        height: caption.visible ? caption.implicitHeight + 10 : 0

        Text {
            id: caption
            x: 2
            width: parent.width - 2
            visible: root.title.length > 0
            text: root.title
            color: "#f0eee7"
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: panel
        y: heading.height
        width: parent.width
        height: body.implicitHeight + root.verticalPadding * 2
        radius: 8
        color: "#0dffffff"
        border.color: "#12ffffff"
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: body
            x: 18
            y: root.verticalPadding
            width: panel.width - 36
            spacing: root.rowSpacing
        }
    }
}
