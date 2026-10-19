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
import ".."
import "../home"

// Compact song lockup for artist pages: artwork, title, then album and year. No index or duration column.
ItemDelegate {
    id: root

    property var track: ({})
    property int trackIndex: 0
    property string fallbackArtist
    property var menuMedia: track
    // Second line names the artist when the song is a feature, else the album.
    property bool showArtist: false
    property color accentSoftColor: "#96caa4"

    readonly property bool current: Boolean(OrchardPlayback.track.id) && OrchardPlayback.track.id === track.id
    readonly property string artistLabel: (track.artists && track.artists.length ? track.artists.join(", ") : "")
                                          || track.artist || fallbackArtist
    readonly property string detailLabel: showArtist ? artistLabel
                                          : [track.album, track.year].filter((part) => !!part).join(" · ")

    signal albumRequested(var album)
    signal artistRequested(var artist)
    signal playlistRequested(var playlist)

    height: 56
    padding: 0
    hoverEnabled: true
    Accessible.name: (track.title || qsTr("Untitled track")) + ", " + artistLabel

    MediaMenu {
        id: trackMenu
        media: root.menuMedia
        onAlbumRequested: function(album) { root.albumRequested(album); }
        onArtistRequested: function(artist) { root.artistRequested(artist); }
        onPlaylistRequested: function(playlist) { root.playlistRequested(playlist); }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: function(point) { trackMenu.popup(root, point.position.x, point.position.y); }
    }

    background: Item {
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -8
            anchors.rightMargin: -8
            radius: 8
            color: root.hovered || trackMenu.visible ? "#12ffffff" : "transparent"
            border.color: root.activeFocus ? root.accentSoftColor : "transparent"
            Behavior on color { ColorAnimation { duration: 110 } }
        }
        // Hairline under the text only, as in a lockup grid.
        Rectangle {
            x: titleBlock.x
            width: parent.width - x
            height: 1
            anchors.bottom: parent.bottom
            color: "#14ffffff"
        }
    }

    contentItem: Item {
        RoundedArtwork {
            id: art
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 5
            source: root.track.thumbnail || ""
        }
        Rectangle {
            anchors.fill: art
            radius: art.radius
            color: "#80000000"
            visible: root.hovered || root.current
        }
        LucideIcon {
            anchors.centerIn: art
            width: 16
            height: 16
            visible: root.hovered || root.current
            name: root.current && OrchardPlayback.playing ? "audio-lines" : "play"
            color: "white"
        }

        Column {
            id: titleBlock
            x: art.width + 12
            width: moreButton.x - x - 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Row {
                width: parent.width
                spacing: 6
                Text {
                    width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 6 : 0))
                    text: root.track.title || qsTr("Untitled track")
                    color: root.current ? root.accentSoftColor : "#f4f4f2"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                ExplicitBadge {
                    id: badge
                    visible: Boolean(root.track.explicit)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#26ffffff"
                    textColor: "#d6d9d4"
                }
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: root.detailLabel
                color: "#99ffffff"
                font.family: "Inter"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        ToolButton {
            id: moreButton
            x: parent.width - width
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter
            padding: 8
            opacity: root.hovered || trackMenu.visible || activeFocus ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: 110 } }
            Accessible.name: qsTr("More options for %1").arg(root.track.title || qsTr("track"))
            onClicked: trackMenu.popup(moreButton, 0, moreButton.height)
            background: Rectangle {
                radius: width / 2
                color: moreButton.hovered ? "#1fffffff" : "transparent"
            }
            contentItem: LucideIcon { name: "ellipsis"; color: "#e6e8e3" }
        }
    }
}
