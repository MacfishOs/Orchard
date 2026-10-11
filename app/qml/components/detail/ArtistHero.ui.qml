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
import "../home"
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Artist banner. Wide fanart goes edge to edge; square portraits get a round avatar.
// fullBleed drops the card and fades the fanart into the page, like mobile.
Item {
    id: root

    property string title: "Artist"
    property string subtitle: ""
    property string banner: ""
    property string portrait: ""
    property bool compact: false
    property bool actionsEnabled: true
    property bool playing: false
    property bool shareEnabled: true
    // Wide artwork can bleed into the page when its aspect ratio leaves room for the title.
    property bool fullBleed: false
    // Extra horizontal padding so bled copy lines up with the page column.
    property int sideInset: 0
    // Page scroll offset, drives the banner parallax.
    property real scrollY: 0
    // Muted music video over the fanart. videoWanted reserves the wide layout before frames arrive.
    property url videoSource: ""
    property bool videoWanted: false
    property bool videoPlaying: true
    property string videoTitle: ""
    // {label, value} pairs for the credit row, e.g. genre, origin, subscribers.
    property var credits: []

    property color accentColor: "#7fbe90"
    property color accentSoftColor: "#96caa4"
    property color accentInkColor: "#09100b"
    property color inkColor: "#080c0a"

    readonly property int pad: compact ? 20 : 32
    // Anything wider than 4:3 is a real banner; squarer images would lose the face to cropping.
    readonly property bool bannerMode: bannerProbe.status === Image.Ready
                                       && bannerProbe.implicitWidth > bannerProbe.implicitHeight * 1.34
    readonly property bool wideMode: bannerMode || videoWanted
    readonly property bool panoramicBanner: root.bannerMode && !root.videoWanted
                                            && bannerProbe.implicitWidth >= bannerProbe.implicitHeight * 3
    // Panoramic banners stay inside the card so the center crop remains predictable.
    readonly property bool bleeding: fullBleed && wideMode && !panoramicBanner
    // Wide, roomy heroes set the name over a ruled row of credits.
    readonly property bool creditMode: wideMode && !compact && !panoramicBanner
    // Text, buttons and credits stacked at the bottom of the card.
    readonly property real stackHeight: creditMode ? copy.height + 24 + creditBlock.height
                                                   : copy.height + 20 + actions.height
    // Open picture area above the name and credits; the video centers on it.
    readonly property real stageHeight: creditMode ? card.height - pad - stackHeight - 24 : card.height
    readonly property bool masked: GraphicsInfo.api !== GraphicsInfo.Software
    // Soft edge width for bled fanart.
    readonly property int feather: compact ? 48 : 96
    // Wide heroes set short names like a title card.
    readonly property int nameSize: compact ? 34 : title.length > 28 ? 44
                                    : title.length > 14 ? 60
                                    : wideMode ? Math.round(Math.max(68, Math.min(92, width * 0.062))) : 76
    readonly property real avatarSize: compact ? 112 : Math.round(Math.max(150, Math.min(208, width * 0.2)))

    property alias playButton: playButton
    property alias shuffleButton: shuffleButton
    property alias shareButton: shareButton
    property alias backdropVideo: backdropVideo
    property alias watchButton: creditBlock.watchButton

    implicitHeight: card.height

    Image {
        id: bannerProbe
        source: root.banner
        asynchronous: true
        visible: false
    }

    Rectangle {
        id: card
        width: root.width
        height: root.bleeding
                ? Math.max(root.stackHeight + root.pad * 2 + 140,
                           Math.round(root.compact ? Math.max(380, root.width * 0.8)
                                                   : Math.max(520, Math.min(780, root.width * 0.52))))
                : !root.wideMode
                ? Math.max(root.stackHeight, root.avatarSize) + root.pad * 2
                : root.compact
                ? Math.max(300, (root.wideMode ? 140 : root.pad + root.avatarSize + 16) + root.stackHeight + root.pad)
                : Math.max(root.stackHeight + root.pad * 2 + 60, Math.round(Math.max(360, Math.min(480, root.width * 0.4))))
        radius: root.bleeding ? 0 : 24
        color: root.bleeding || !root.wideMode ? "transparent" : root.inkColor
        layer.enabled: root.masked && !root.bleeding && root.wideMode
        layer.effect: MultiEffect { maskEnabled: true; maskSource: cardMask }

        Rectangle {
            id: cardMask
            anchors.fill: parent
            radius: parent.radius
            visible: false
            layer.enabled: true
        }

        // Alpha ramps so bled fanart melts into the page on every side; two passes because masks don't multiply.
        Rectangle {
            id: fadeMask
            anchors.fill: parent
            visible: false
            layer.enabled: root.bleeding
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: root.feather / Math.max(1, card.height); color: "white" }
                GradientStop { position: 0.5; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            id: edgeMask
            anchors.fill: parent
            visible: false
            layer.enabled: root.bleeding
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: root.feather / Math.max(1, card.width); color: "white" }
                GradientStop { position: 1 - root.feather / Math.max(1, card.width); color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Item {
            id: artFrame
            anchors.fill: parent
            // No fanart: just the round portrait, no backdrop.
            visible: root.wideMode
            layer.enabled: root.masked && root.bleeding
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: edgeMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Item {
                id: art
                anchors.fill: parent
                // Layers clip on their own; the software renderer needs telling.
                clip: root.bleeding
                layer.enabled: root.masked && root.bleeding
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: fadeMask
                    // Centered threshold with full spread maps mask alpha to a linear fade.
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                // Portrait mode backdrop: blur at thumbnail size, then upscale for a cheap soft glow.
                Item {
                    width: 24
                    height: 24
                    visible: !root.bannerMode
                    opacity: 0.85
                    layer.enabled: visible
                    layer.smooth: true
                    transform: Scale { xScale: card.width / 24; yScale: card.height / 24 }

                    Image {
                        id: wash
                        anchors.fill: parent
                        source: root.portrait
                        fillMode: Image.Stretch
                        sourceSize.width: 32
                        asynchronous: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: wash
                        blurEnabled: true
                        blurMax: 16
                        blur: 1
                        saturation: 0.35
                    }
                }

                Image {
                    id: bannerImage
                    width: parent.width
                    // Oversized so the parallax drift never exposes the card edge.
                    height: root.panoramicBanner ? parent.height : parent.height * 1.25
                    y: root.panoramicBanner ? 0 : -Math.min(Math.max(root.scrollY, 0) * 0.3, parent.height * 0.25)
                    source: root.banner
                    fillMode: Image.PreserveAspectCrop
                    // Fanart keeps heads near the top; crop from the bottom.
                    verticalAlignment: Image.AlignTop
                    asynchronous: true
                    opacity: root.bannerMode ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }

                // Fanart or the portrait wash holds the frame until the video has pictures.
                // Centered on the stage so the subject clears the text. Drift is capped at a tenth so the
                // box still reaches the card bottom without zooming the picture far in.
                ArtistBackdropVideo {
                    id: backdropVideo
                    width: parent.width
                    height: parent.height * 2.2 - root.stageHeight
                    y: (root.stageHeight - height) / 2 - Math.min(Math.max(root.scrollY, 0) * 0.15, parent.height * 0.1)
                    source: root.videoSource
                    playing: root.videoPlaying
                    visible: hasVideo
                    opacity: live ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 1000; easing.type: Easing.InOutQuad } }
                }
                // Music videos run brighter than fanart; keep the title readable.
                Rectangle {
                    anchors.fill: parent
                    color: root.inkColor
                    opacity: backdropVideo.opacity * 0.22
                    visible: opacity > 0
                }

                // Scrims: bottom fade for the name, left fade for the buttons.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.18) }
                        GradientStop { position: 0.4; color: "transparent" }
                        GradientStop { position: 0.78; color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.55) }
                        GradientStop { position: 1; color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.92) }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !root.compact
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.5) }
                        GradientStop { position: 0.55; color: "transparent" }
                    }
                }
            }
        }

        Item {
            id: avatar
            visible: !root.wideMode || root.panoramicBanner
            x: root.compact ? (card.width - width) / 2 : root.pad
            y: root.compact ? root.pad : actions.y + actions.height - height
            width: root.avatarSize
            height: root.avatarSize

            Rectangle {
                id: avatarShadowSource
                anchors.fill: parent
                radius: width / 2
                color: "black"
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: avatarShadowSource
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowBlur: 1
                shadowOpacity: 0.5
                shadowVerticalOffset: 14
                shadowColor: "black"
            }
            RoundedArtwork {
                anchors.fill: parent
                radius: width / 2
                source: root.portrait
            }
            LucideIcon {
                anchors.centerIn: parent
                width: 56
                height: 56
                name: "circle-user-round"
                color: Qt.rgba(root.accentSoftColor.r, root.accentSoftColor.g, root.accentSoftColor.b, 0.7)
                visible: !root.portrait
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: "#1fffffff"
            }
        }

        Column {
            id: copy
            x: root.compact || (root.wideMode && !root.panoramicBanner)
               ? root.pad + root.sideInset : avatar.x + avatar.width + 32
            y: root.creditMode ? creditBlock.y - 24 - height : actions.y - 20 - height
            width: card.width - x - root.pad - root.sideInset - (root.creditMode ? actions.width + 32 : 0)
            spacing: 0

            Row {
                visible: !root.creditMode
                spacing: 12

                Text {
                    text: qsTr("ARTIST")
                    color: Qt.rgba(root.accentSoftColor.r, root.accentSoftColor.g, root.accentSoftColor.b, 0.95)
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 2.4
                }
            }
            Item { width: 1; height: root.creditMode ? 0 : 6 }
            Text {
                width: parent.width
                text: root.title
                color: "#f7f5f0"
                font.family: "Inter"
                font.pixelSize: root.nameSize
                font.weight: root.creditMode ? Font.ExtraBold : Font.Black
                font.letterSpacing: root.compact ? -0.8 : -root.nameSize * 0.04
                lineHeight: root.wideMode ? 0.9 : 0.94
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                // Lift the name off busy fanart without a visible box.
                layer.enabled: root.wideMode && GraphicsInfo.api !== GraphicsInfo.Software
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 0.6
                    shadowOpacity: 0.45
                    shadowVerticalOffset: 2
                }
            }
            Item { width: 1; height: subtitleText.visible ? 8 : 0 }
            Text {
                id: subtitleText
                width: parent.width
                visible: !root.creditMode && text.length > 0
                text: root.subtitle
                color: "#d4d8d2"
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        // Under the name in portrait and compact layouts; right of it, play outermost, in credit mode.
        Row {
            id: actions
            x: root.creditMode ? card.width - root.pad - root.sideInset - width : copy.x
            y: root.creditMode ? creditBlock.y - 24 - height : card.height - root.pad - height
            spacing: root.creditMode ? 10 : 12
            layoutDirection: root.creditMode ? Qt.RightToLeft : Qt.LeftToRight

            Button {
                id: playButton
                width: root.creditMode ? 60 : 56
                height: width
                enabled: root.actionsEnabled
                opacity: enabled ? 1 : 0.4
                Accessible.name: root.playing ? qsTr("Pause") : qsTr("Play %1").arg(root.title)
                scale: down ? 0.94 : hovered ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                background: Rectangle {
                    radius: width / 2
                    color: playButton.hovered ? Qt.lighter(root.accentColor, 1.08) : root.accentColor
                    border.color: playButton.activeFocus ? "white" : "transparent"
                    border.width: 2
                }
                contentItem: Item {
                    LucideIcon {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: root.playing ? 0 : 2
                        width: 24
                        height: 24
                        name: root.playing ? "pause" : "play"
                        color: root.accentInkColor
                    }
                }
            }
            ArtistHeroGhostButton {
                id: shuffleButton
                anchors.verticalCenter: parent.verticalCenter
                accentSoftColor: root.accentSoftColor
                glyph: "shuffle"
                enabled: root.actionsEnabled
                Accessible.name: qsTr("Shuffle")
                ToolTip.text: qsTr("Shuffle")
            }
            ArtistHeroGhostButton {
                id: shareButton
                anchors.verticalCenter: parent.verticalCenter
                accentSoftColor: root.accentSoftColor
                glyph: "share-2"
                enabled: root.shareEnabled
                Accessible.name: qsTr("Copy artist link")
                ToolTip.text: qsTr("Copy artist link")
            }
        }

        ArtistHeroCredits {
            id: creditBlock
            visible: root.creditMode
            x: root.pad + root.sideInset
            y: card.height - root.pad - height
            width: card.width - x - root.pad - root.sideInset
            credits: root.credits
            videoTitle: root.videoTitle
            videoLive: backdropVideo.live
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: !root.bleeding && root.wideMode
            color: "transparent"
            border.color: "#14ffffff"
        }
    }
}
