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

// Small tinted label used for release state and channel.
Rectangle {
    id: root

    property string text
    property color tone: "#8cc5a5"

    implicitWidth: label.implicitWidth + 14
    implicitHeight: 20
    radius: height / 2
    color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.16)
    border.color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.34)

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.tone
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }
}
