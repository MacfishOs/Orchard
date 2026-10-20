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
import QtQuick.Layouts
import ".."

// Accent and popup background colors. Changes apply live across the app.
SettingsSection {
    id: root

    title: qsTr("Colors")
    rowSpacing: 0
    verticalPadding: 0

    SettingsRow {
        iconName: "palette"
        title: qsTr("Accent color")
        description: OrchardAppearance.accentMode === "artwork"
            ? qsTr("Follows the cover of the song that's playing, and uses your color when nothing is.")
            : qsTr("Used for switches, sliders, and the page you're on.")

        SettingsSegmented {
            currentValue: OrchardAppearance.accentMode
            model: [
                { value: "custom", label: qsTr("Pick a color") },
                { value: "artwork", label: qsTr("Match album art") }
            ]
            onPicked: value => OrchardAppearance.accentMode = value
        }
    }

    SettingsRow {
        ColorSwatchRow {
            Layout.fillWidth: true
            Layout.leftMargin: 38
            Layout.topMargin: 4
            Layout.bottomMargin: 6
            presets: OrchardAppearance.accentPresets
            current: OrchardAppearance.accentColor
            dialogTitle: qsTr("Accent color")
            onPicked: value => {
                OrchardAppearance.accentColor = value;
                OrchardAppearance.accentMode = "custom";
            }
        }
    }

    SettingsRow {
        iconName: "app-window"
        title: qsTr("Menu and popup background")
        description: qsTr("The color behind menus, dialogs, and this window.")
    }

    SettingsRow {
        ColorSwatchRow {
            Layout.fillWidth: true
            Layout.leftMargin: 38
            Layout.topMargin: -6
            Layout.bottomMargin: 6
            presets: OrchardAppearance.popupPresets
            current: OrchardAppearance.popupColor
            darkCheck: false
            dialogTitle: qsTr("Popup background")
            onPicked: value => OrchardAppearance.popupColor = value
        }
    }

    SettingsRow {
        AppearanceSlider {
            Layout.fillWidth: true
            Layout.leftMargin: 38
            label: qsTr("See-through frosted popups")
            from: 0
            to: 0.8
            stepSize: 0.05
            value: OrchardAppearance.popupTranslucency
            displayValue: Math.round(OrchardAppearance.popupTranslucency * 100) + "%"
            onMoved: value => OrchardAppearance.popupTranslucency = value
        }
    }

    SettingsRow {
        SettingsHint {
            Layout.fillWidth: true
            Layout.leftMargin: 38
            text: qsTr("Release notes and Connect are frosted and let the music show through. Menus, Docs, and bug reports stay solid so they're easy to read.")
        }

        SettingsButton {
            text: qsTr("Reset colors")
            onClicked: OrchardAppearance.resetColors()
        }
    }
}
