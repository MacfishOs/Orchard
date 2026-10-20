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

// Toggle with its state spelled out beside it, Windows style.
Switch {
    id: control

    readonly property color accent: OrchardAppearance.accent

    hoverEnabled: true
    text: checked ? qsTr("On") : qsTr("Off")
    spacing: 12
    padding: 0
    implicitWidth: stateLabel.implicitWidth + spacing + 40
    implicitHeight: 32

    contentItem: Text {
        id: stateLabel
        text: control.text
        rightPadding: 40 + control.spacing
        color: control.enabled ? "#f0eee7" : "#7c857f"
        font.family: "Inter"
        font.pixelSize: 14
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
    }

    indicator: Rectangle {
        implicitWidth: 40
        implicitHeight: 20
        x: control.width - width
        y: (control.height - height) / 2
        radius: 10
        opacity: control.enabled ? 1 : 0.45
        color: control.checked
               ? (control.down ? Qt.darker(control.accent, 1.12) : control.hovered ? Qt.lighter(control.accent, 1.08) : control.accent)
               : control.hovered ? "#14ffffff" : "transparent"
        border.width: control.checked ? 0 : 1
        border.color: "#c3c8c4"
        Behavior on color { ColorAnimation { duration: Motion.normal } }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 6
            height: parent.height + 6
            radius: height / 2
            visible: control.visualFocus
            color: "transparent"
            border.color: OrchardAppearance.accentStrong
            border.width: 2
        }

        Rectangle {
            readonly property real size: control.hovered || control.down ? 14 : 12
            // Stretches while held, then springs to the far side.
            width: control.down ? size + 4 : size
            height: size
            radius: size / 2
            x: control.checked ? parent.width - width - 4 : 4
            y: (parent.height - height) / 2
            color: control.checked ? OrchardAppearance.onAccent : "#d0d4d1"
            Behavior on x { NumberAnimation { duration: Motion.slow; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
            Behavior on width { NumberAnimation { duration: Motion.fast; easing.type: Motion.enter } }
            Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Motion.enter } }
            Behavior on color { ColorAnimation { duration: Motion.normal } }
        }
    }
}
