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
import QtQuick.Layouts

// Dropdown used by the integration cards.
ComboBox {
    id: select

    Layout.fillWidth: true
    implicitHeight: 32
    font.family: "Inter"
    font.pixelSize: 13
    hoverEnabled: true

    contentItem: Text {
        leftPadding: 14
        rightPadding: select.indicator.width + 14
        text: select.displayText
        font: select.font
        color: "#f0eee7"
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: LucideIcon {
        x: select.width - width - 14
        y: (select.height - height) / 2
        width: 14
        height: 14
        name: "chevron-right"
        color: "#a4aaa1"
        rotation: select.popup.visible ? -90 : 90
        Behavior on rotation { NumberAnimation { duration: Motion.slow; easing.type: Easing.OutBack } }
    }

    background: Rectangle {
        radius: 5
        color: select.popup.visible ? "#0affffff" : select.hovered ? "#18ffffff" : "#10ffffff"
        border.color: select.visualFocus ? OrchardAppearance.accentStrong : "#14ffffff"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    delegate: ItemDelegate {
        id: option
        required property int index
        required property var modelData
        width: ListView.view.width
        implicitHeight: 36
        highlighted: select.highlightedIndex === index

        contentItem: Text {
            text: option.modelData
            leftPadding: 6
            color: select.currentIndex === option.index ? OrchardAppearance.accentStrong : "#f0eee7"
            font: select.font
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 5
            color: option.highlighted ? "#14ffffff" : "transparent"
        }
    }

    popup: Popup {
        y: select.height + 6
        width: select.width
        padding: 5
        implicitHeight: contentItem.implicitHeight + 10

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: select.popup.visible ? select.delegateModel : null
            currentIndex: select.highlightedIndex
        }
        background: Rectangle {
            radius: 8
            color: OrchardAppearance.popupColor
            border.color: "#1fffffff"
        }
    }
}
