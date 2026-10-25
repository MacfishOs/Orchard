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

// Glass player bar: a floating pill (glade) or a slim rectangle (canopy). Lives outside the backdrop it blurs, or the capture would eat itself.
Item {
    id: root

    required property Item backdrop
    property bool backdropLive: false
    property bool queueOpen: false

    signal queueRequested()
    signal expandRequested()
    signal miniPlayerRequested()
    signal albumRequested(var album)
    signal artistRequested(var artist)
    signal playlistRequested(var playlist)

    readonly property bool canopy: OrchardAppearance.layoutStyle === "canopy"
    readonly property bool compact: width < (canopy ? 960 : 760)
    readonly property bool showTrackInfo: !canopy || width >= 500
    readonly property bool showProgress: !canopy || width >= 700
    readonly property real cornerRadius: canopy ? 10 : height / 2
    readonly property int controlSize: canopy ? 28 : 32
    // The fullscreen player launches its cover from here.
    readonly property Item artworkItem: artworkSlot
    readonly property var artPalette: artworkPalette.palette

    readonly property color accentColor: theme.accent
    readonly property color onAccentColor: theme.onAccent
    readonly property color inkColor: theme.ink
    // The next song's accent, lifted so dots read on the dark track.
    readonly property color mixAccentColor: {
        const value = (incomingPalette.palette || {})["accent"];
        const c = value && value.length >= 3
            ? Qt.rgba(Number(value[0]) / 255, Number(value[1]) / 255, Number(value[2]) / 255, 1)
            : root.accentColor;
        // Achromatic covers report hue -1; keep them grey.
        const sat = c.hslHue < 0 || c.hslSaturation < 0.08 ? 0 : Math.max(c.hslSaturation, 0.45);
        return Qt.hsla(Math.max(0, c.hslHue), sat, Math.max(c.hslLightness, 0.72), 1);
    }

    readonly property color primaryText: "#f5f3ee"
    readonly property color secondaryText: "#b4b8b1"
    readonly property color controlColor: "#e6e4dc"
    readonly property color trackColor: "#33ffffff"

    function paletteColor(key, fallback) {
        const value = (root.artPalette || {})[key];
        const color = value && value.length >= 3 ? value : fallback;
        return Qt.rgba(Number(color[0]) / 255, Number(color[1]) / 255, Number(color[2]) / 255, 1);
    }

    function tint(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    // While driving another device, the slider is that device's volume.
    readonly property real volumeLevel: OrchardConnect.controlling ? OrchardConnect.remoteVolume : OrchardHome.volume

    function setVolumeLevel(value) {
        if (OrchardConnect.controlling)
            OrchardConnect.setRemoteVolume(value);
        else
            OrchardHome.volume = value;
    }

    function refreshBackdrop() {
        glass.refresh();
    }

    function timeLabel(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "0:00";

        const total = Math.floor(seconds);
        const minutes = Math.floor(total / 60);
        const remaining = total % 60;
        return minutes + ":" + String(remaining).padStart(2, "0");
    }

    function formatBitrate(value) {
        const num = Number(value || 0);
        if (!Number.isFinite(num) || num <= 0)
            return "";
        return String(Math.round(num >= 1000 ? num / 1000 : num));
    }

    // Untyped on purpose: a compiled binding reading the track map trips qmlcachegen.
    function qobuzLabel(track) {
        if (!track || track.playbackSource !== "qobuz")
            return "";
        const parts = [track.hires ? qsTr("Hi-Res") : qsTr("Lossless")];
        if (track.bitDepth || track.sampleRate) {
            const depth = track.bitDepth ? qsTr("%1-bit").arg(track.bitDepth) : "";
            const rate = track.sampleRate ? qsTr("%1 kHz").arg(Number((track.sampleRate / 1000).toFixed(1))) : "";
            parts.push([depth, rate].filter(Boolean).join(" / "));
        }
        if (track.streamCodec)
            parts.push(track.streamCodec);
        return parts.join(" · ");
    }

    // Streamed songs: bitrate then codec, e.g. "128 kbps · Opus". Needs the bitrate setting.
    function streamLabel(track) {
        if (!OrchardAppearance.showBitrate || OrchardPlayback.bitrate <= 0)
            return "";
        const parts = [root.formatBitrate(OrchardPlayback.bitrate) + " kbps"];
        if (track && track.streamCodec)
            parts.push(track.streamCodec);
        return parts.join(" · ");
    }

    // Files from this computer always say what they are, e.g. "FLAC · 1411 kbps",
    // using the bitrate the decoder reports. No setting needed; there is no stream to hide.
    function localLabel(track) {
        if (!track || String(track.id || "").indexOf("local:") !== 0)
            return "";
        const rate = root.formatBitrate(OrchardPlayback.bitrate);
        const codec = track.codec ? String(track.codec).toUpperCase() : "";
        return [codec, rate ? rate + " kbps" : ""].filter(Boolean).join(" · ");
    }

    implicitHeight: canopy ? 52 : 64

    ArtworkPalette {
        id: artworkPalette

        // Recolor at the crossfade midpoint so the pill follows what you hear.
        source: OrchardPlayback.crossfadeActive && OrchardPlayback.crossfadeProgress >= 0.5
                ? (OrchardPlayback.transitionTrack.thumbnail || "")
                : (OrchardPlayback.track.thumbnail || "")
    }

    ArtworkPalette {
        id: incomingPalette
        source: OrchardPlayback.crossfadeActive ? (OrchardPlayback.transitionTrack.thumbnail || "") : ""
    }

    // Explicit fade: a Behavior on these custom color properties crashes QQmlData::deferData (Qt 6).
    // A new cover eases the whole pill into its colors instead of slapping them on.
    Item {
        id: theme

        readonly property color accentTarget: root.paletteColor("accent", [240, 238, 231])
        // Thin outlined glyphs need more contrast than the palette's tinted onAccent gives.
        readonly property color onAccentTarget: {
            const lin = (c) => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
            const luminance = 0.2126 * lin(accentTarget.r) + 0.7152 * lin(accentTarget.g) + 0.0722 * lin(accentTarget.b);
            return luminance > 0.18 ? "#121212" : "#ffffff";
        }
        readonly property color inkTarget: root.paletteColor("ink", [11, 13, 10])
        property color accent
        property color onAccent
        property color ink

        visible: false
        onAccentTargetChanged: fade.restart()
        onOnAccentTargetChanged: fade.restart()
        onInkTargetChanged: fade.restart()
        // Standard Cutefish accent theme
        onAccentChanged: {}
        Component.onCompleted: {
            accent = accentTarget;
            onAccent = onAccentTarget;
            ink = inkTarget;
        }

        ParallelAnimation {
            id: fade

            ColorAnimation { target: theme; property: "accent"; to: theme.accentTarget; duration: 600; easing.type: Easing.OutCubic }
            ColorAnimation { target: theme; property: "onAccent"; to: theme.onAccentTarget; duration: 600; easing.type: Easing.OutCubic }
            ColorAnimation { target: theme; property: "ink"; to: theme.inkTarget; duration: 600; easing.type: Easing.OutCubic }
        }
    }

    MediaMenu {
        id: mediaMenu
        media: OrchardPlayback.track
        onAlbumRequested: function(album) { root.albumRequested(album); }
        onArtistRequested: function(artist) { root.artistRequested(artist); }
        onPlaylistRequested: function(playlist) { root.playlistRequested(playlist); }
    }

    // Swallow presses, hover and wheel so the page underneath stays out of it. Glass is not a door.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: function(wheel) { wheel.accepted = true; }
    }

    // Apple Music macOS style floating glass player pill
    Glass {
        id: glass

        anchors.fill: parent
        backdrop: root.backdrop
        radius: root.cornerRadius
        live: root.backdropLive
        shadowOpacity: 0.35
        shadowSpread: 20
        shadowOffsetY: 10
        edgeHighlight: 0.20
        blurRadius: 36
    }

    // Clean neutral frosted translucent surface overlay (no artwork color tinting)
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(0.14, 0.14, 0.16, 0.65)
    }

    // Thin Apple-style specular edge border
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.12)
    }

    // Top specular highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.cornerRadius
        anchors.rightMargin: root.cornerRadius
        height: 1
        color: Qt.rgba(255, 255, 255, 0.16)
    }

    // Edge glow swells to the handoff and settles, in the incoming palette after the midpoint.
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1.5
        border.color: root.tint(Qt.lighter(root.accentColor, 1.3), 0.7)
        opacity: OrchardPlayback.crossfadeActive ? Math.sin(Math.PI * Math.max(0, Math.min(1, OrchardPlayback.crossfadeProgress))) : 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.canopy ? 16 : 24
        anchors.rightMargin: root.canopy ? 16 : 24
        spacing: 16

        // Left: Transport controls (Shuffle, Prev, Play, Next, Repeat)
        PlayerTransportControls {
            bar: root
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        }

        // Center: macOS style LCD Display / Floating Track Capsule
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 520
            Layout.alignment: Qt.AlignCenter
            Layout.topMargin: 7
            Layout.bottomMargin: 7
            color: Qt.rgba(0, 0, 0, 0.28)
            border.color: Qt.rgba(255, 255, 255, 0.12)
            border.width: 1
            radius: 10
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 8

                // Artwork inside the LCD
                Item {
                    id: artworkSlot
                    readonly property real artRadius: 6
                    Layout.preferredWidth: parent.height - 8
                    Layout.preferredHeight: Layout.preferredWidth
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Open now playing")
                    Keys.onReturnPressed: root.expandRequested()
                    Keys.onSpacePressed: root.expandRequested()

                    Rectangle {
                        anchors.fill: parent
                        radius: artworkSlot.artRadius
                        color: "#22ffffff"
                        border.color: parent.activeFocus ? root.accentColor : "transparent"
                    }

                    TransitionArtwork {
                        anchors.fill: parent
                        source: OrchardPlayback.track.thumbnail || ""
                        incomingSource: OrchardPlayback.transitionTrack.thumbnail || ""
                        transitioning: OrchardPlayback.crossfadeActive
                        progress: OrchardPlayback.crossfadeProgress
                        radius: artworkSlot.artRadius
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 600
                        ToolTip.text: qsTr("Open now playing")
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) mediaMenu.popup(parent, mouse.x, mouse.y);
                            else if (OrchardPlayback.track.id) root.expandRequested();
                        }
                    }
                }

                // Track Info & Progress Stacked
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MixSwapText {
                            id: titleText
                            Layout.fillWidth: true
                            Layout.maximumWidth: 220
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: mediaMenu.albumId ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) mediaMenu.popup(parent, mouse.x, mouse.y);
                                    else mediaMenu.viewAlbum();
                                }
                            }
                            activeFocusOnTab: Boolean(mediaMenu.albumId)
                            Accessible.role: Accessible.Link
                            Accessible.name: text
                            font.underline: activeFocus
                            Keys.onReturnPressed: mediaMenu.viewAlbum()
                            Keys.onSpacePressed: mediaMenu.viewAlbum()
                            text: OrchardPlayback.track.title || qsTr("Not Playing")
                            incomingText: OrchardPlayback.transitionTrack.title || ""
                            transitioning: OrchardPlayback.crossfadeActive
                            progress: OrchardPlayback.crossfadeProgress
                            color: root.primaryText
                            font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignLeft
                        }

                        ExplicitBadge {
                            id: explicitBadge
                            visible: Boolean(OrchardPlayback.track.explicit)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        SlopBadge {
                            id: slopBadge
                            trackId: OrchardPlayback.track.id || ""
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "•"
                            color: Qt.rgba(255, 255, 255, 0.35)
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignVCenter
                            visible: Boolean(OrchardPlayback.track.title) && Boolean(trackStatus.text.length)
                        }

                        MixSwapText {
                            id: trackStatus
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            function artistOf(track) {
                                const joined = (track.artists || []).join(", ");
                                return joined || track.artist || "";
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: mediaMenu.artistIds.length ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) mediaMenu.popup(parent, mouse.x, mouse.y);
                                    else mediaMenu.viewArtist(parent, mouse.x, mouse.y);
                                }
                            }
                            activeFocusOnTab: mediaMenu.artistIds.length > 0
                            Accessible.role: Accessible.Link
                            Accessible.name: text
                            font.underline: activeFocus
                            Keys.onReturnPressed: mediaMenu.viewArtist(trackStatus, 0, trackStatus.height)
                            Keys.onSpacePressed: mediaMenu.viewArtist(trackStatus, 0, trackStatus.height)
                            text: artistOf(OrchardPlayback.track)
                            incomingText: artistOf(OrchardPlayback.transitionTrack)
                            transitioning: OrchardPlayback.crossfadeActive
                            progress: OrchardPlayback.crossfadeProgress
                            color: root.secondaryText
                            font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            horizontalAlignment: Text.AlignLeft
                        }

                        Rectangle {
                            id: bitratePill
                            visible: bitrateLabel.text.length > 0
                            Layout.alignment: Qt.AlignVCenter
                            Accessible.role: Accessible.StaticText
                            Accessible.name: bitrateLabel.text
                            width: bitrateLabel.implicitWidth + 8
                            height: 14
                            radius: 4
                            color: Qt.rgba(255, 255, 255, 0.12)
                            border.color: Qt.rgba(255, 255, 255, 0.15)
                            border.width: 1

                            Text {
                                id: bitrateLabel
                                anchors.centerIn: parent
                                text: OrchardConnect.controlling ? qsTr("On %1").arg(OrchardConnect.peer.name)
                                      : root.qobuzLabel(OrchardPlayback.track)
                                      || root.localLabel(OrchardPlayback.track)
                                      || root.streamLabel(OrchardPlayback.track)
                                color: "#ffffff"
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    PlayerProgressRow {
                        bar: root
                        Layout.fillWidth: true
                        Layout.topMargin: -4
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // Right side: Volume and side controls
        RowLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 8

            LikeButton {
                visible: !root.compact
                iconColor: root.controlColor
                likedColor: root.accentColor
            }

            SkipNonMusicButton {
                compact: true
                textColor: root.controlColor
            }

            PlayerSideControls { bar: root; onMiniPlayerRequested: root.miniPlayerRequested() }
        }
    }
}
