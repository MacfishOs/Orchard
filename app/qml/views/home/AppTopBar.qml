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

    signal settingsRequested
    signal docsRequested
    signal supportRequested

    readonly property real buttonsLeft: offlineStatus.visible ? offlineStatus.x : supportButton.x
    readonly property real canopyPlayerWidth: Math.max(0, buttonsLeft - 12)

    OfflineStatusButton {
        id: offlineStatus

        anchors.right: supportButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }

    Button {
        id: supportButton

        anchors.right: docsButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        onClicked: root.supportRequested()
        Accessible.name: OrchardSupport.unread > 0 ? qsTr("Report a bug, %1 updates").arg(OrchardSupport.unread) : qsTr("Report a bug")
        ToolTip.visible: hovered
        ToolTip.text: OrchardSupport.unread > 0 ? qsTr("Bug reports have updates") : qsTr("Report a bug")

        background: Rectangle {
            radius: 19
            color: supportButton.hovered ? "#12ffffff" : "#00ffffff"

            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }

        contentItem: LucideIcon {
            name: "bug"
            color: supportButton.hovered ? "#f1eee7" : "#bec4c7"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        // News on a report. The bug button finally has something to say.
        Rectangle {
            x: parent.width - width - 7
            y: 7
            width: 8
            height: 8
            radius: 4
            color: "#8cc5a5"
            border.color: "#0d0f12"
            visible: OrchardSupport.unread > 0
        }
    }

    Button {
        id: docsButton

        anchors.right: account.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        onClicked: root.docsRequested()
        Accessible.name: qsTr("Docs")
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Docs")

        background: Rectangle {
            radius: 19
            color: docsButton.hovered ? "#12ffffff" : "#00ffffff"

            Behavior on color {
                ColorAnimation { duration: Motion.fast }
            }
        }

        contentItem: LucideIcon {
            name: "book-open"
            color: docsButton.hovered ? "#f1eee7" : "#bec4c7"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
    }

    Button {
        id: account

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: 42
        onClicked: root.settingsRequested()
        Accessible.name: qsTr("Account and settings")
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
    }
}
