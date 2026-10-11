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
import QtQuick.Controls

// Ruled credit row under the artist name, with the backdrop clip's title at the right end.
Item {
    id: root

    // {label, value} pairs, left to right.
    property var credits: [
        { label: "Genre", value: "Indie Pop" },
        { label: "From", value: "London, UK" },
        { label: "Subscribers", value: "25.5M" }
    ]
    property string videoTitle: ""
    property bool videoLive: false

    property alias watchButton: watchButton

    implicitHeight: 1 + 18 + Math.max(creditRow.height, nowShowing.height)

    Rectangle {
        width: parent.width
        height: 1
        color: "#38e8eeec"
    }

    Row {
        id: creditRow
        y: 19
        width: parent.width - (nowShowing.visible ? nowShowing.width + 24 : 0)
        spacing: 24

        Repeater {
            model: root.credits

            delegate: Column {
                required property var modelData

                width: Math.min(200, (creditRow.width - creditRow.spacing * 3) / 4)
                spacing: 6

                Text {
                    text: modelData.label
                    color: "#94a39e"
                    font.family: "Inter"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.2
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    width: parent.width
                    text: modelData.value
                    color: "#eef2f0"
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }
        }
    }

    // Selecting the title opens the clip with sound.
    Column {
        id: nowShowing
        visible: root.videoTitle.length > 0
        opacity: root.videoLive ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        x: parent.width - width
        y: 19
        width: 220
        spacing: 6

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: qsTr("NOW SHOWING")
            color: "#94a39e"
            font.family: "Inter"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 2.2
        }
        Button {
            id: watchButton
            anchors.right: parent.right
            width: Math.min(parent.width, implicitContentWidth)
            height: 20
            padding: 0
            enabled: nowShowing.opacity > 0
            Accessible.name: qsTr("Watch %1").arg(root.videoTitle)
            ToolTip.text: qsTr("Watch video")
            ToolTip.visible: hovered
            background: null
            contentItem: Text {
                text: root.videoTitle
                color: watchButton.hovered ? "white" : "#eef2f0"
                font.family: "Inter"
                font.pixelSize: 14
                font.weight: Font.Medium
                font.underline: watchButton.hovered || watchButton.activeFocus
                elide: Text.ElideRight
            }
        }
    }
}
