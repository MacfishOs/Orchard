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
import ".."

// One setting inside a SettingsSection: icon, title, description, control on the right.
Item {
    id: root
    property string iconName
    property string title
    property string description
    // Children land in the trailing slot; with no title they fill the row.
    default property alias controls: slot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(64, content.implicitHeight + 28)

    // The first row of a panel sits at y 0 and gets no divider.
    Rectangle {
        visible: root.y > 0
        x: -18
        width: parent.width + 36
        height: 1
        color: "#0fffffff"
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        LucideIcon {
            visible: root.iconName.length > 0
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.rightMargin: 2
            name: root.iconName
            color: root.enabled ? "#e8ebe8" : "#7c857f"
        }

        ColumnLayout {
            visible: root.title.length > 0
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.enabled ? "#f4f4f2" : "#92998f"
                font.family: "Inter"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                color: "#b9bfba"
                font.family: "Inter"
                font.pixelSize: 12
                lineHeight: 1.1
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            id: slot
            Layout.fillWidth: root.title.length === 0
            Layout.alignment: Qt.AlignVCenter
            spacing: 10
        }
    }
}
