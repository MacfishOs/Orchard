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
import QtQuick.Layouts
import ".."

ComboBox {
    id: control
    implicitHeight: 32
    leftPadding: 12
    rightPadding: 38
    hoverEnabled: true
    font.family: "Inter"
    font.pixelSize: 13

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: "#f0eee7"
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    indicator: LucideIcon {
        x: control.width - width - 14
        y: (control.height - height) / 2
        width: 14
        height: 14
        name: "chevron-down"
        color: "#c3c8c4"
        rotation: control.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Motion.slow; easing.type: Easing.OutBack } }
    }

    background: Rectangle {
        radius: 5
        color: control.down || control.popup.visible ? "#0affffff" : control.hovered ? "#18ffffff" : "#10ffffff"
        border.color: control.visualFocus ? OrchardAppearance.accentStrong : "#14ffffff"
        opacity: control.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    delegate: ItemDelegate {
        id: option
        required property var modelData
        required property int index
        width: control.popup.width - 12
        height: 36
        leftPadding: 12
        rightPadding: 12
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: option.modelData[control.textRole] ?? option.modelData
            font: control.font
            leftPadding: 6
            color: "#f0eee7"
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 5
            color: option.highlighted || option.hovered ? "#14ffffff" : control.currentIndex === option.index ? "#0cffffff" : "transparent"

            Rectangle {
                visible: control.currentIndex === option.index
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 16
                radius: 1.5
                color: OrchardAppearance.accent
            }
        }
    }

    popup: Popup {
        y: control.height + 4
        transformOrigin: Item.Top
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Motion.enter }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Motion.normal; easing.type: Motion.enter }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast; easing.type: Motion.exit }
        }
        width: Math.max(control.width, 220)
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 280)
        padding: 6

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle {
            radius: 8
            color: OrchardAppearance.popupColor
            border.color: "#1fffffff"
        }
    }
}
