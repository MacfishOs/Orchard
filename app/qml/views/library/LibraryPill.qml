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

import "../../components"
import Orchard
import QtQuick
import QtQuick.Controls

// Pill button for the library header: category tabs and Refresh.
Button {
    id: root

    property string iconName
    // Muted trailing text, e.g. an item count.
    property string detail
    property bool busy: false

    implicitHeight: 32
    implicitWidth: content.implicitWidth + (iconName ? 28 : 30)
    hoverEnabled: true

    background: Rectangle {
        radius: height / 2
        color: root.checked ? "#2a7af6" : root.hovered ? "#35353a" : "#28282c"
        border.color: root.activeFocus ? OrchardAppearance.accentStrong : "transparent"
        opacity: root.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: Motion.normal } }
    }

    contentItem: Item {
        Row {
            id: content
            anchors.centerIn: parent
            spacing: 8

            LucideIcon {
                visible: root.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                name: root.iconName
                color: root.checked ? "#ffffff" : "#c2c2c6"

                // Finishes the turn it is on, so the icon never freezes crooked.
                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.busy
                    alwaysRunToEnd: true
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.checked ? "#ffffff" : "#c2c2c6"
                font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                font.pixelSize: 13
                font.weight: root.checked ? Font.DemiBold : Font.Normal
                Behavior on color { ColorAnimation { duration: Motion.normal } }
            }
            Text {
                visible: root.detail !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.detail
                color: root.checked ? "#d0e0ff" : "#8d968e"
                font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                font.pixelSize: 12
                font.features: { "tnum": 1 }
            }
        }
    }
}
