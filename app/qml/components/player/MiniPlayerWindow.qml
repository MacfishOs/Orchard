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
import QtQuick.Window

// macOS Apple Music style floating MiniPlayer window.
Window {
    id: miniPlayer

    required property Window parentWindow

    title: qsTr("MiniPlayer")
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    property bool expandedArt: false
    readonly property real windowCornerRadius: 14
    readonly property color accentColor: OrchardAppearance.accentColor || "#fa2d48"
    readonly property color primaryText: "#ffffff"
    readonly property color secondaryText: "#98989d"

    width: expandedArt ? 300 : 380
    height: expandedArt ? 360 : 78
    minimumWidth: 320
    minimumHeight: 78

    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    function openPlayer() {
        if (!visible) {
            if (parentWindow) {
                x = Math.max(50, parentWindow.x + parentWindow.width - width - 24);
                y = Math.max(50, parentWindow.y + 40);
            }
            visible = true;
            raise();
            requestActivate();
        }
    }

    function returnToMain() {
        visible = false;
        if (parentWindow) {
            parentWindow.showNormal();
            parentWindow.raise();
            parentWindow.requestActivate();
        }
    }

    function timeLabel(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
        const total = Math.floor(seconds);
        return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
    }

    function remainingLabel(sliderVal) {
        if (OrchardPlayback.displayDuration <= 0) return "-:--";
        const cur = sliderVal !== undefined ? sliderVal : OrchardPlayback.displayPosition;
        return "-" + timeLabel(Math.max(0, OrchardPlayback.displayDuration - cur));
    }

    Shortcut { sequence: "Space"; onActivated: OrchardPlayback.toggle() }
    Shortcut { sequence: "Esc"; onActivated: miniPlayer.returnToMain() }
    Shortcut { sequence: "Ctrl+Shift+M"; onActivated: miniPlayer.returnToMain() }

    Rectangle {
        id: windowFrame
        anchors.fill: parent
        anchors.margins: 4
        radius: miniPlayer.windowCornerRadius
        color: Qt.rgba(0.12, 0.12, 0.15, 0.90)
        border.color: Qt.rgba(255, 255, 255, 0.14)
        border.width: 1
        clip: true

        DragHandler {
            target: null
            grabPermissions: PointerHandler.ApprovesTakeOverByAnything
            onActiveChanged: if (active) miniPlayer.startSystemMove()
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(255, 255, 255, 0.18)
        }

        // Top Header: Traffic light buttons (macOS Red, Yellow, Green)
        Row {
            id: trafficLights
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10
            spacing: 7
            z: 20

            Rectangle {
                width: 12; height: 12; radius: 6
                color: closeHover.containsPress ? "#bf4038" : "#ff5f56"
                border.color: Qt.rgba(0, 0, 0, 0.25); border.width: 0.5
                MouseArea {
                    id: closeHover; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: miniPlayer.visible = false
                }
            }

            Rectangle {
                width: 12; height: 12; radius: 6
                color: minHover.containsPress ? "#d9a11e" : "#ffbd2e"
                border.color: Qt.rgba(0, 0, 0, 0.25); border.width: 0.5
                MouseArea {
                    id: minHover; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: miniPlayer.showMinimized()
                }
            }

            Rectangle {
                width: 12; height: 12; radius: 6
                color: zoomHover.containsPress ? "#1fa12b" : "#27c93f"
                border.color: Qt.rgba(0, 0, 0, 0.25); border.width: 0.5
                MouseArea {
                    id: zoomHover; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: miniPlayer.returnToMain()
                }
            }
        }

        Button {
            id: viewModeToggle
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            z: 20
            implicitWidth: 22; implicitHeight: 22
            hoverEnabled: true; focusPolicy: Qt.NoFocus
            ToolTip.visible: hovered; ToolTip.delay: 400
            ToolTip.text: miniPlayer.expandedArt ? qsTr("Compact view") : qsTr("Artwork view")
            onClicked: miniPlayer.expandedArt = !miniPlayer.expandedArt
            background: Rectangle {
                radius: 4
                color: viewModeToggle.hovered ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
            }
            contentItem: LucideIcon {
                name: miniPlayer.expandedArt ? "minimize" : "maximize"
                color: viewModeToggle.hovered ? "#ffffff" : "#a1a1a6"
                implicitWidth: 12; implicitHeight: 12
            }
        }

        // --- COMPACT VIEW ---
        RowLayout {
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10
            visible: !miniPlayer.expandedArt

            Item {
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignVCenter
                Rectangle {
                    anchors.fill: parent; radius: 6; color: "#22ffffff"; clip: true
                    TransitionArtwork {
                        anchors.fill: parent
                        source: OrchardPlayback.track.thumbnail || ""
                        incomingSource: OrchardPlayback.transitionTrack.thumbnail || ""
                        transitioning: OrchardPlayback.crossfadeActive
                        progress: OrchardPlayback.crossfadeProgress
                        radius: 6
                    }
                }
                Rectangle {
                    anchors.fill: parent; radius: 6; color: "transparent"
                    border.color: Qt.rgba(255, 255, 255, 0.12); border.width: 1
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: miniPlayer.expandedArt = true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text {
                        text: OrchardPlayback.track.title || qsTr("Not Playing")
                        color: miniPlayer.primaryText
                        font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                        font.pixelSize: 12; font.weight: Font.DemiBold
                        elide: Text.ElideRight; Layout.maximumWidth: 130
                    }
                    ExplicitBadge {
                        visible: Boolean(OrchardPlayback.track.explicit)
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: "•"; color: Qt.rgba(255, 255, 255, 0.35); font.pixelSize: 10
                        visible: Boolean(OrchardPlayback.track.title) && Boolean(artistCompact.text.length)
                    }
                    Text {
                        id: artistCompact
                        text: (OrchardPlayback.track.artists || []).join(", ") || OrchardPlayback.track.artist || ""
                        color: miniPlayer.secondaryText
                        font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                        font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text {
                        text: miniPlayer.timeLabel(compactSeek.pressed ? compactSeek.value : OrchardPlayback.displayPosition)
                        color: "#8e8e93"; font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                        font.pixelSize: 9; font.weight: Font.DemiBold
                    }
                    Slider {
                        id: compactSeek
                        Layout.fillWidth: true; implicitHeight: 14
                        from: 0; to: Math.max(1, OrchardPlayback.displayDuration)
                        value: pressed ? value : OrchardPlayback.displayPosition
                        enabled: OrchardPlayback.duration > 0 && !OrchardPlayback.loading && !OrchardPlayback.errorMessage
                        live: true; hoverEnabled: true
                        onPressedChanged: if (!pressed && enabled) OrchardPlayback.seek(value)
                        background: Rectangle {
                            y: (parent.height - height) / 2; width: parent.width; height: 3
                            radius: 1.5; color: Qt.rgba(255, 255, 255, 0.18)
                            Rectangle {
                                width: compactSeek.visualPosition * parent.width
                                height: parent.height; radius: parent.radius; color: "#ffffff"
                            }
                        }
                        handle: Rectangle {
                            x: compactSeek.leftPadding + compactSeek.visualPosition * (compactSeek.availableWidth - width)
                            y: (compactSeek.height - height) / 2
                            width: 8; height: 8; radius: 4; color: "#ffffff"
                            scale: compactSeek.pressed || compactSeek.hovered ? 1 : 0
                            opacity: scale > 0 ? 1 : 0
                            Behavior on scale { NumberAnimation { duration: 90 } }
                        }
                    }
                    Text {
                        text: miniPlayer.remainingLabel(compactSeek.pressed ? compactSeek.value : undefined)
                        color: "#8e8e93"; font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                        font.pixelSize: 9; font.weight: Font.DemiBold
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter; spacing: 4
                Button {
                    implicitWidth: 26; implicitHeight: 26; hoverEnabled: true; focusPolicy: Qt.NoFocus
                    enabled: OrchardPlayback.canGoPrevious; onClicked: OrchardPlayback.previous()
                    background: Rectangle { radius: width / 2; color: parent.hovered ? Qt.rgba(255, 255, 255, 0.10) : "transparent" }
                    contentItem: LucideIcon { name: "skip-back"; color: "#ffffff"; implicitWidth: 14; implicitHeight: 14; opacity: parent.enabled ? 1 : 0.4 }
                }
                Button {
                    implicitWidth: 30; implicitHeight: 30; hoverEnabled: true; focusPolicy: Qt.NoFocus
                    enabled: Boolean(OrchardPlayback.track.id); onClicked: OrchardPlayback.toggle()
                    background: Rectangle {
                        radius: width / 2; color: parent.down ? "#d8d8dc" : "#ffffff"
                        scale: parent.down ? 0.94 : parent.hovered ? 1.05 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                    contentItem: LucideIcon { name: OrchardPlayback.playing ? "pause" : "play"; color: "#16161a"; implicitWidth: 15; implicitHeight: 15 }
                }
                Button {
                    implicitWidth: 26; implicitHeight: 26; hoverEnabled: true; focusPolicy: Qt.NoFocus
                    enabled: OrchardPlayback.canGoNext; onClicked: OrchardPlayback.next()
                    background: Rectangle { radius: width / 2; color: parent.hovered ? Qt.rgba(255, 255, 255, 0.10) : "transparent" }
                    contentItem: LucideIcon { name: "skip-forward"; color: "#ffffff"; implicitWidth: 14; implicitHeight: 14; opacity: parent.enabled ? 1 : 0.4 }
                }
            }
        }

        // --- ARTWORK VIEW ---
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 26
            spacing: 8
            visible: miniPlayer.expandedArt

            Item {
                Layout.preferredWidth: 264; Layout.preferredHeight: 220
                Layout.alignment: Qt.AlignHCenter
                Rectangle {
                    anchors.fill: parent; radius: 10; color: "#22ffffff"; clip: true
                    TransitionArtwork {
                        anchors.fill: parent
                        source: OrchardPlayback.track.thumbnail || ""
                        incomingSource: OrchardPlayback.transitionTrack.thumbnail || ""
                        transitioning: OrchardPlayback.crossfadeActive
                        progress: OrchardPlayback.crossfadeProgress
                        radius: 10
                    }
                }
                Rectangle {
                    anchors.fill: parent; radius: 10; color: "transparent"
                    border.color: Qt.rgba(255, 255, 255, 0.12); border.width: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    text: OrchardPlayback.track.title || qsTr("Not Playing")
                    color: miniPlayer.primaryText; font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                    font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true
                }
                Text {
                    text: (OrchardPlayback.track.artists || []).join(", ") || OrchardPlayback.track.artist || ""
                    color: miniPlayer.secondaryText; font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                    font.pixelSize: 11; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text {
                    text: miniPlayer.timeLabel(artSeek.pressed ? artSeek.value : OrchardPlayback.displayPosition)
                    color: "#8e8e93"; font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                    font.pixelSize: 9; font.weight: Font.DemiBold
                }
                Slider {
                    id: artSeek
                    Layout.fillWidth: true; implicitHeight: 14
                    from: 0; to: Math.max(1, OrchardPlayback.displayDuration)
                    value: pressed ? value : OrchardPlayback.displayPosition
                    enabled: OrchardPlayback.duration > 0 && !OrchardPlayback.loading && !OrchardPlayback.errorMessage
                    live: true; hoverEnabled: true
                    onPressedChanged: if (!pressed && enabled) OrchardPlayback.seek(value)
                    background: Rectangle {
                        y: (parent.height - height) / 2; width: parent.width; height: 3
                        radius: 1.5; color: Qt.rgba(255, 255, 255, 0.18)
                        Rectangle {
                            width: artSeek.visualPosition * parent.width
                            height: parent.height; radius: parent.radius; color: "#ffffff"
                        }
                    }
                    handle: Rectangle {
                        x: artSeek.leftPadding + artSeek.visualPosition * (artSeek.availableWidth - width)
                        y: (artSeek.height - height) / 2
                        width: 8; height: 8; radius: 4; color: "#ffffff"
                        scale: artSeek.pressed || artSeek.hovered ? 1 : 0
                        opacity: scale > 0 ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                }
                Text {
                    text: miniPlayer.remainingLabel(artSeek.pressed ? artSeek.value : undefined)
                    color: "#8e8e93"; font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                    font.pixelSize: 9; font.weight: Font.DemiBold
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 18
                Button {
                    implicitWidth: 30; implicitHeight: 30; hoverEnabled: true; focusPolicy: Qt.NoFocus
                    enabled: OrchardPlayback.canGoPrevious; onClicked: OrchardPlayback.previous()
                    background: Rectangle { radius: width / 2; color: parent.hovered ? Qt.rgba(255, 255, 255, 0.10) : "transparent" }
                    contentItem: LucideIcon { name: "skip-back"; color: "#ffffff"; implicitWidth: 16; implicitHeight: 16; opacity: parent.enabled ? 1 : 0.4 }
                }
                Button {
                    implicitWidth: 36; implicitHeight: 36; hoverEnabled: true; focusPolicy: Qt.NoFocus
                    enabled: Boolean(OrchardPlayback.track.id); onClicked: OrchardPlayback.toggle()
                    background: Rectangle {
                        radius: width / 2; color: parent.down ? "#d8d8dc" : "#ffffff"
                        scale: parent.down ? 0.94 : parent.hovered ? 1.05 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                    contentItem: LucideIcon { name: OrchardPlayback.playing ? "pause" : "play"; color: "#16161a"; implicitWidth: 18; implicitHeight: 18 }
                }
                Button {
                    implicitWidth: 30; implicitHeight: 30; hoverEnabled: true; focusPolicy: Qt.NoFocus
                    enabled: OrchardPlayback.canGoNext; onClicked: OrchardPlayback.next()
                    background: Rectangle { radius: width / 2; color: parent.hovered ? Qt.rgba(255, 255, 255, 0.10) : "transparent" }
                    contentItem: LucideIcon { name: "skip-forward"; color: "#ffffff"; implicitWidth: 16; implicitHeight: 16; opacity: parent.enabled ? 1 : 0.4 }
                }
            }
        }
    }
}
