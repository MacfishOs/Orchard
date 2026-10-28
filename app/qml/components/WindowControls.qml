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

Row {
    id: root

    required property Window targetWindow
    property bool autoHide: false
    property bool awake: true
    readonly property bool hovered: closeArea.containsMouse || minArea.containsMouse || maxArea.containsMouse
    readonly property real shown: !autoHide || awake || hovered ? 1 : 0

    function wake() {
        awake = true;
        idleTimer.restart();
    }

    spacing: 8
    height: 28
    opacity: 1.0
    visible: shown > 0.01

    Timer {
        id: idleTimer
        interval: 2200
        onTriggered: root.awake = false
    }

    // Close Button (macOS Red)
    Rectangle {
        id: closeBtn
        width: 14
        height: 14
        radius: 7
        color: closeArea.containsPress ? "#e0443e" : "#ff5f56"
        border.color: Qt.rgba(0, 0, 0, 0.25)
        border.width: 1
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 1.5
            radius: 0.75
            color: "#4a0002"
            rotation: 45
            visible: closeArea.containsMouse || closeArea.containsPress
        }
        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 1.5
            radius: 0.75
            color: "#4a0002"
            rotation: -45
            visible: closeArea.containsMouse || closeArea.containsPress
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.targetWindow) root.targetWindow.close()
        }
    }

    // Minimize Button (macOS Yellow)
    Rectangle {
        id: minBtn
        width: 14
        height: 14
        radius: 7
        color: minArea.containsPress ? "#dea123" : "#ffbd2e"
        border.color: Qt.rgba(0, 0, 0, 0.25)
        border.width: 1
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 1.5
            radius: 0.75
            color: "#5b3d00"
            visible: minArea.containsMouse || minArea.containsPress
        }

        MouseArea {
            id: minArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.targetWindow) root.targetWindow.showMinimized()
        }
    }

    // Maximize Button (macOS Green)
    Rectangle {
        id: maxBtn
        width: 14
        height: 14
        radius: 7
        color: maxArea.containsPress ? "#1aab29" : "#27c93f"
        border.color: Qt.rgba(0, 0, 0, 0.25)
        border.width: 1
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 1.5
            radius: 0.75
            color: "#003206"
            visible: maxArea.containsMouse || maxArea.containsPress
        }
        Rectangle {
            anchors.centerIn: parent
            width: 1.5
            height: 7
            radius: 0.75
            color: "#003206"
            visible: maxArea.containsMouse || maxArea.containsPress
        }

        MouseArea {
            id: maxArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (!root.targetWindow) return;
                if (mouse.button === Qt.RightButton) {
                    tileMenu.popup(maxBtn, 0, maxBtn.height + 4);
                } else {
                    if (root.targetWindow.visibility === Window.Maximized)
                        root.targetWindow.showNormal();
                    else
                        root.targetWindow.showMaximized();
                }
            }
        }
    }

    Menu {
        id: tileMenu
        width: 160
        padding: 5
        background: Rectangle { color: "#28282c"; radius: 8; border.color: "#20ffffff" }

        component Entry: MenuItem {
            id: entry
            implicitHeight: 32
            background: Rectangle {
                radius: 6
                color: entry.highlighted ? "#2a7af6" : "transparent"
            }
            contentItem: Text {
                text: entry.text
                color: "#ffffff"
                font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
        }

        Entry {
            text: root.targetWindow && root.targetWindow.visibility === Window.Maximized ? qsTr("Restore Window") : qsTr("Fill Screen")
            onTriggered: {
                if (!root.targetWindow) return;
                if (root.targetWindow.visibility === Window.Maximized)
                    root.targetWindow.showNormal();
                else
                    root.targetWindow.showMaximized();
            }
        }
    }
}
