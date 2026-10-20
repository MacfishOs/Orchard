/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts

SettingsSection {
    id: root
    title: qsTr("Lyrics providers")
    rowSpacing: 0
    verticalPadding: 0

    SettingsRow {
        iconName: "audio-lines"
        title: qsTr("Provider priority")
        description: qsTr("Try enabled providers from top to bottom. The first lyrics found are used. You can also choose a source for one song in the lyrics player.")
    }

    Repeater {
        model: OrchardLyrics.providerSettings.providers
        delegate: SettingsRow {
            id: row
            required property var modelData
            required property int index
            title: modelData.name
            description: modelData.enabled ? qsTr("Priority %1").arg(index + 1) : qsTr("Disabled")

            RowLayout {
                spacing: 6
                SettingsButton {
                    text: "↑"
                    enabled: row.index > 0
                    Accessible.name: qsTr("Move %1 up").arg(row.modelData.name)
                    onClicked: OrchardLyrics.providerSettings.moveProvider(row.index, row.index - 1)
                }
                SettingsButton {
                    text: "↓"
                    enabled: row.index < OrchardLyrics.providerSettings.providers.length - 1
                    Accessible.name: qsTr("Move %1 down").arg(row.modelData.name)
                    onClicked: OrchardLyrics.providerSettings.moveProvider(row.index, row.index + 1)
                }
                SettingsSwitch {
                    checked: row.modelData.enabled
                    Accessible.name: qsTr("Enable %1").arg(row.modelData.name)
                    onToggled: OrchardLyrics.providerSettings.setEnabled(row.modelData.id, checked)
                }
            }
        }
    }
}
