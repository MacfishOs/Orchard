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
import "../../components"
import "../../components/home"

Item {
    id: root

    property var shell
    signal settingsRequested

    readonly property real buttonsLeft: offlineStatus.visible ? offlineStatus.x : account.x
    readonly property real canopyPlayerWidth: Math.max(0, buttonsLeft - 12)

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Button {
            id: backButton
            width: 32
            height: 32
            enabled: root.shell ? root.shell.history.length > 0 : false
            opacity: enabled ? 1 : 0.35
            ToolTip.visible: hovered && enabled
            ToolTip.text: qsTr("Back")
            Accessible.name: qsTr("Back")
            onClicked: if (root.shell) root.shell.goBack()

            background: Rectangle {
                radius: 16
                color: backButton.hovered && backButton.enabled ? "#24ffffff" : "#10ffffff"
                border.color: backButton.activeFocus ? OrchardAppearance.accent : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
            contentItem: LucideIcon {
                anchors.centerIn: parent
                name: "chevron-left"
                width: 16
                height: 16
                color: backButton.enabled ? "#ffffff" : "#66ffffff"
            }
        }
    }

    OfflineStatusButton {
        id: offlineStatus

        anchors.right: account.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }

    Button {
        id: account

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: 42
        onClicked: root.settingsRequested()
        Accessible.name: OrchardSupport.unread > 0 ? qsTr("Account and settings, bug reports have updates") : qsTr("Account and settings")
        ToolTip.visible: hovered
        ToolTip.text: OrchardAuth.userName || qsTr("Account and settings")

        background: Rectangle {
            radius: 21
            color: account.hovered ? "#12ffffff" : "#00ffffff"

            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }

        padding: 0

        contentItem: Item {
            RoundedArtwork {
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: 18
                source: OrchardAuth.userAvatar || ""
            }
        }

        // News on a bug report; the reports themselves live in Settings.
        Rectangle {
            x: parent.width - width - 3
            y: 3
            width: 10
            height: 10
            radius: 5
            color: OrchardAppearance.accent
            border.color: "#0d0f12"
            border.width: 2
            visible: OrchardSupport.unread > 0
        }
    }
}
