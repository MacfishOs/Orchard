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

// Ambient glow from a 3x3 grid of colors. The cells render into a 3x3 texture that is
// upscaled with linear filtering, so neighbouring colors blend across the whole window.
Item {
    id: root

    // Row-major, nine colors.
    property var colors: []
    readonly property bool ready: colors.length === 9

    Item {
        id: cells

        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(3, 3)

        Repeater {
            model: 9

            Rectangle {
                required property int index

                x: (index % 3) * cells.width / 3
                y: Math.floor(index / 3) * cells.height / 3
                width: cells.width / 3 + 1
                height: cells.height / 3 + 1
                color: root.ready ? root.colors[index] : "#0f1512"
                Behavior on color { ColorAnimation { duration: 1400; easing.type: Easing.InOutSine } }
            }
        }
    }

    // Settles the edges toward the page ink so the sidebar and player read the same as elsewhere.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 1; color: "#59000000" }
        }
    }
}
