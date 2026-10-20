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

pragma ComponentBehavior: Bound
import Orchard
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import ".."

// Preset swatches plus a custom color button. presets: [{ name, color }]
ColumnLayout {
    id: root

    property var presets: []
    property color current: "white"
    property string customLabel: qsTr("Custom color")
    property string dialogTitle: qsTr("Pick a color")
    // Light swatches get a dark check so it stays visible.
    property bool darkCheck: true

    signal picked(color value)

    readonly property bool customSelected: {
        for (const entry of root.presets) {
            if (Qt.colorEqual(entry.color, root.current))
                return false;
        }
        return true;
    }

    spacing: 12

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: root.presets

            delegate: AbstractButton {
                id: swatch
                required property var modelData
                readonly property bool selected: Qt.colorEqual(modelData.color, root.current)

                width: 40
                height: 40
                hoverEnabled: true
                Accessible.name: modelData.name
                Accessible.role: Accessible.RadioButton
                Accessible.checked: selected
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: modelData.name
                onClicked: root.picked(modelData.color)

                background: Rectangle {
                    radius: 6
                    color: swatch.modelData.color
                    border.color: "#24ffffff"
                    scale: swatch.down ? 0.92 : swatch.hovered ? 1.08 : 1
                    Behavior on scale { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutBack } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: 9
                        color: "transparent"
                        border.width: 2
                        border.color: swatch.visualFocus ? OrchardAppearance.accentStrong : "#ffffff"
                        opacity: swatch.selected || swatch.visualFocus ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }
                }

                contentItem: Item {
                    LucideIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        name: "check"
                        color: root.darkCheck ? "#111311" : "#ffffff"
                        scale: swatch.selected ? 1 : 0.4
                        opacity: swatch.selected ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: Motion.slow; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }
                }
            }
        }
    }

    RowLayout {
        spacing: 10

        SettingsButton {
            text: root.customLabel
            onClicked: dialog.open()
        }

        Rectangle {
            visible: root.customSelected
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: 6
            color: root.current
            border.color: "#40ffffff"
        }

        Text {
            visible: root.customSelected
            text: String(root.current).toUpperCase()
            color: "#b9bfba"
            font.family: "Inter"
            font.pixelSize: 12
        }
    }

    ColorDialog {
        id: dialog
        title: root.dialogTitle
        selectedColor: root.current
        onAccepted: root.picked(selectedColor)
    }
}
