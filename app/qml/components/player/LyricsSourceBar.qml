/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import "../settings"
import QtQuick

Item {
    id: root
    property color accentColor: "#f0eee7"
    property color primaryText: "#f5f3ee"
    readonly property var providers: OrchardLyrics.providerSettings.providers.filter(provider => provider.enabled)
    implicitHeight: 40

    function sourceLabel(source) {
        return OrchardLyrics.providerSettings.label(source);
    }

    SettingsSelect {
        id: sourcePicker
        anchors.left: parent.left
        width: Math.min(180, parent.width * 0.55)
        height: 40
        visible: !OrchardLyrics.trackId.startsWith("local:")
        model: [qsTr("Automatic")].concat(root.providers.map(provider => provider.name))
        currentIndex: root.providers.findIndex(provider => provider.id === OrchardLyrics.selectedProvider) + 1
        displayText: OrchardLyrics.selectedProvider || !OrchardLyrics.source
            ? currentText : qsTr("Auto · %1").arg(root.sourceLabel(OrchardLyrics.source))
        Accessible.name: qsTr("Lyrics source for this song")
        onActivated: index => OrchardLyrics.selectProvider(index > 0 ? root.providers[index - 1].id : "")
    }

    LyricsTranslateBar {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (sourcePicker.visible ? sourcePicker.width + 6 : 0)
        visible: OrchardLyrics.status === "ready"
        clip: true
        accentColor: root.accentColor
        primaryText: root.primaryText
    }
}
