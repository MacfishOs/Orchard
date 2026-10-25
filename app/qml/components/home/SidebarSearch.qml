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

Rectangle {
    id: root

    property bool compact: false
    property alias query: search.text
    readonly property string searchLabel: OrchardNetwork.offline ? qsTr("Search your downloads")
        : OrchardHome.homeSource === "apple_music" ? qsTr("Search Apple Music") : qsTr("Search YouTube Music")

    signal searchChanged(string query)
    signal spotlightRequested

    function focusSearch() {
        if (compact)
            spotlightButton.forceActiveFocus();
        else
            search.forceActiveFocus();
    }

    function clearSearch() { search.clear(); }

    height: 30
    radius: 6
    color: search.activeFocus ? "#1affffff" : "#10ffffff"
    border.color: search.activeFocus || spotlightButton.activeFocus ? OrchardAppearance.accent : "transparent"
    Behavior on color { ColorAnimation { duration: Motion.fast } }
    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

    LucideIcon {
        x: root.compact ? (parent.width - width) / 2 : 10
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        name: "search"
        color: "#a6adb2"
    }

    TextField {
        id: search

        anchors.fill: parent
        visible: !root.compact
        leftPadding: 31
        rightPadding: clearButton.visible ? 29 : 10
        placeholderText: qsTr("Search")
        placeholderTextColor: "#929ba1"
        color: "#f1eee7"
        font.pixelSize: 12
        selectByMouse: true
        Accessible.name: root.searchLabel
        onTextChanged: root.searchChanged(text)
        background: Item {}
    }

    Button {
        id: clearButton

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 3
        width: 24
        height: 24
        visible: !root.compact && search.text.length > 0
        Accessible.name: qsTr("Clear search")
        onClicked: {
            root.clearSearch();
            root.focusSearch();
        }
        background: Rectangle {
            radius: 6
            color: clearButton.hovered || clearButton.activeFocus ? "#20ffffff" : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        contentItem: LucideIcon {
            name: "x"
            color: "#c1c7ca"
        }
        padding: 5
    }

    Button {
        id: spotlightButton

        anchors.fill: parent
        visible: root.compact
        Accessible.name: root.searchLabel
        ToolTip.visible: hovered
        ToolTip.text: root.searchLabel
        onClicked: root.spotlightRequested()
        background: Rectangle {
            radius: 8
            color: spotlightButton.hovered ? "#12ffffff" : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        contentItem: Item {}
    }
}
