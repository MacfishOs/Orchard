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

import "../../components"
import "../../components/home"
import "../../components/detail"
import QtQuick
import QtQuick.Window

// Artist page. Layout lives in ArtistViewForm.ui.qml; this file binds the artist model and handles input.
// Backstage crew only: the form keeps the spotlight.
ArtistViewForm {
    id: root

    readonly property var sections: detail.sections || []
    readonly property var artistPalette: OrchardArtist.palette || ({})
    // First entry of the artist's Videos shelf, when the backdrop setting is on.
    readonly property var backdropVideo: {
        if (!OrchardAppearance.artistVideoBackdrop)
            return null;
        const shelf = sections.find((section) => sectionKind(section) === "videos");
        const items = shelf && shelf.items || [];
        return items.find((item) => item && item.id) || null;
    }
    // Feeds the shell's ambient colors while the backdrop has moving pictures.
    readonly property bool samplingVideo: hero.backdropVideo.live && heroVideoPlaying
    readonly property bool containsCurrent: {
        const id = OrchardPlayback.track.id;
        return Boolean(id) && tracks.some((track) => track.id === id);
    }

    signal backRequested()
    signal albumRequested(var album)
    signal artistRequested(var artist)
    signal playlistRequested(var playlist)
    signal unsupportedRequested(var media)

    detail: OrchardArtist.detail || ({})
    tracks: detail.tracks || []
    // Discography first, then videos, then everyone else's shelves.
    orderedSections: sections
        .map((section, index) => ({ section, index }))
        .sort((left, right) => sectionRank(left.section) - sectionRank(right.section) || left.index - right.index)
        .map((entry) => entry.section)
    latestRelease: detail.latestRelease || null
    latestCaption: cardCaption(latestRelease || ({}))
    expandedKind: sectionKind(expandedSection || ({}))
    expandedAlbumWidth: albumWidthFor(expandedSection || ({}))
    loading: OrchardArtist.loading
    errorMessage: OrchardArtist.errorMessage
    browseIdentity: detail.browseId || ""
    collectionPlaying: containsCurrent && OrchardPlayback.playing
    playerInset: scroll.playerInset
    heroMeta: [detail.subtitle].concat((detail.facts || [])
        .filter((fact) => fact.key === "genre" || fact.key === "origin")
        .map((fact) => fact.value))
        .filter(Boolean).join(" · ")
    heroCredits: {
        const facts = detail.facts || [];
        const fact = (key) => (facts.find((entry) => entry.key === key) || {}).value || "";
        // "25.5M subscribers" becomes a SUBSCRIBERS credit of 25.5M.
        const audience = String(detail.subtitle || "").match(/^([\d.,]+\s*[KMB]?)\s+(.+)$/i);
        return [
            { label: qsTr("Genre"), value: fact("genre") },
            { label: qsTr("From"), value: fact("origin") },
            audience ? { label: audience[2], value: audience[1] } : { label: "", value: "" },
            { label: qsTr("Active since"), value: fact("formed") }
        ].filter((credit) => credit.label && credit.value);
    }
    heroVideoWanted: !!backdropVideo && OrchardArtistVideo.status !== "error"
    heroVideoSource: backdropVideo && OrchardArtistVideo.videoId === backdropVideo.id ? OrchardArtistVideo.source : ""
    heroVideoTitle: backdropVideo ? backdropVideo.title || "" : ""
    // Runs only while the hero is on screen and the window is shown.
    heroVideoPlaying: visible && !expandedSection && scroll.contentY < hero.height
                      && Window.visibility !== Window.Minimized && Window.visibility !== Window.Hidden
    accentColor: rgb(artistPalette.accent, [127, 190, 144])
    accentSoftColor: rgb(artistPalette.accentSoft, [150, 202, 164])
    deepColor: rgb(artistPalette.deep, [15, 21, 18])
    inkColor: rgb(artistPalette.ink, [8, 12, 10])
    accentInkColor: rgb(artistPalette.onAccent, [9, 16, 11])

    function rgb(value, fallback) {
        const color = value && value.length >= 3 ? value : fallback;
        return Qt.rgba(Number(color[0]) / 255, Number(color[1]) / 255, Number(color[2]) / 255, 1);
    }

    function sectionKind(section) {
        const title = String(section && section.title || "").toLowerCase();
        if (/singles?|\beps?\b/.test(title))
            return "singles";
        if (/albums?/.test(title))
            return "albums";
        if (/videos?/.test(title))
            return "videos";
        if (/fans|similar|also like|related/.test(title))
            return "related";
        return "other";
    }

    function sectionRank(section) {
        return ["albums", "singles", "videos", "other", "related"].indexOf(sectionKind(section));
    }

    // Albums get the big covers; 65 singles would rather not.
    function albumWidthFor(section) {
        const kind = sectionKind(section);
        return kind === "albums" ? 184 : kind === "singles" ? 140 : 158;
    }

    function cardCaption(media) {
        if (media.releaseYear || media.releaseType)
            return [media.releaseYear, media.releaseType === "Album" ? "" : media.releaseType].filter(Boolean).join(" · ");
        // Every card here is theirs, so drop the artist's own name.
        const name = String(detail.title || "").toLowerCase();
        return String(media.subtitle || "").split(/\s*[•·]\s*/).filter((part) => part && part.toLowerCase() !== name).join(" · ");
    }

    function openSection(section) {
        expandedSection = section;
        sectionGrid.contentY = sectionGrid.originY;
        sectionGrid.forceActiveFocus();
    }

    function closeSection() {
        expandedSection = null;
        root.forceActiveFocus();
    }

    function activate(media) {
        if (media.type === "artist")
            artistRequested(media);
        else if (media.type === "album")
            albumRequested(media);
        else if (media.type === "playlist")
            playlistRequested(media);
    }

    function playOrToggle() {
        if (containsCurrent)
            OrchardPlayback.toggle();
        else
            OrchardPlayback.playCollection(tracks, 0, false);
    }

    onSamplingVideoChanged: OrchardArtistVideo.watchFrames(samplingVideo ? hero.backdropVideo.sink : null)
    Component.onDestruction: OrchardArtistVideo.watchFrames(null)

    onBrowseIdentityChanged: {
        expandedSection = null;
        scroll.contentY = 0;
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.expandedSection)
                root.closeSection();
            else
                root.backRequested();
            event.accepted = true;
        }
    }

    backButton.onClicked: root.backRequested()
    pageLoad.onRetryRequested: OrchardArtist.retry()
    moreButton.onClicked: aboutText.expanded = !aboutText.expanded

    hero.playButton.onClicked: root.playOrToggle()
    hero.shuffleButton.onClicked: OrchardPlayback.playCollection(root.tracks, 0, true)
    hero.watchButton.onClicked: if (root.backdropVideo) root.unsupportedRequested(root.backdropVideo)
    hero.backdropVideo.onFailed: OrchardArtistVideo.retry()
    hero.shareButton.onClicked: OrchardBackend.copyToClipboard("https://music.youtube.com/channel/" + root.browseIdentity, qsTr("Copied artist link to clipboard"))

    stickyBar.onPlayClicked: root.playOrToggle()
    stickyBar.onBackToTopClicked: scroll.contentY = 0

    latestCard.onActivated: function(media) { root.activate(media); }
    latestCard.onAlbumRequested: function(album) { root.albumRequested(album); }
    latestCard.onArtistRequested: function(artist) { root.artistRequested(artist); }
    latestCard.onPlaylistRequested: function(playlist) { root.playlistRequested(playlist); }

    popularList.delegate: CollectionTrackRow {
        id: song

        required property var modelData
        required property int index

        width: parent.width
        track: modelData
        trackIndex: index
        showArtwork: true
        showAlbum: !root.compact
        // Features earn a second line; the headliner's name is already 76px tall.
        showArtist: song.artistLabel !== (root.detail.title || "")
        fallbackArtist: root.detail.title || ""
        menuMedia: Object.assign({}, modelData, {
            "artistBrowseIds": modelData.artistBrowseIds && modelData.artistBrowseIds.length ? modelData.artistBrowseIds : [root.browseIdentity]
        })
        accentColor: root.accentColor
        accentSoftColor: root.accentSoftColor
        onClicked: OrchardPlayback.playCollection(root.tracks, index, false)
        onAlbumRequested: function(album) { root.albumRequested(album); }
        onArtistRequested: function(artist) { root.artistRequested(artist); }
        onPlaylistRequested: function(playlist) { root.playlistRequested(playlist); }
    }

    shelfList.delegate: Item {
        required property var modelData
        required property int index

        width: parent.width
        height: shelf.height + 18

        ShelfView {
            id: shelf

            y: 18
            width: parent.width
            section: modelData
            sectionIndex: index
            songsEnabled: true
            seeAllEnabled: true
            albumWidth: root.albumWidthFor(modelData)
            captionFor: root.cardCaption
            animatedArtist: root.detail.title || ""
            onSeeAllRequested: root.openSection(modelData)
            onSongRequested: function(song) {
                const items = modelData.items || [];
                const selectedIndex = items.findIndex(track => track.id === song.id);
                if (selectedIndex >= 0) OrchardPlayback.playCollection(items, selectedIndex);
                else OrchardPlayback.playSong(song);
            }
            onUnsupportedRequested: function(media) { root.unsupportedRequested(media); }
            onMediaRequested: function(media) { root.activate(media); }
            onAlbumRequested: function(album) { root.albumRequested(album); }
            onArtistRequested: function(artist) { root.artistRequested(artist); }
            onPlaylistRequested: function(playlist) { root.playlistRequested(playlist); }
            onVerticalScrollRequested: function(delta, smooth) { root.scroll.scrollBy(delta, smooth); }
        }
    }

    sectionGrid.delegate: MediaCard {
        required property var modelData

        width: root.sectionGrid.cellWidth - 14
        media: modelData
        presentation: root.sectionGrid.presentation
        caption: root.cardCaption(modelData)
        animatedArtist: root.detail.title || ""
        playbackBlocked: media.type === "video"
        navigable: media.type === "album" || media.type === "artist" || media.type === "playlist"
        onActivated: function(media) {
            if (playbackBlocked)
                root.unsupportedRequested(media);
            else
                root.activate(media);
        }
        onAlbumRequested: function(album) { root.albumRequested(album); }
        onArtistRequested: function(artist) { root.artistRequested(artist); }
        onPlaylistRequested: function(playlist) { root.playlistRequested(playlist); }
    }

    Binding {
        target: OrchardArtistVideo
        property: "targetHeight"
        value: root.hero.backdropVideo.pixelHeight
    }

    // Leaving the page releases the stream.
    Binding {
        target: OrchardArtistVideo
        property: "videoId"
        value: root.visible && root.backdropVideo ? root.backdropVideo.id : ""
    }

    // The grid's Back button lives in its header delegate, so it is wired through the header item.
    Connections {
        // qmllint disable missing-property
        target: root.sectionGrid.headerItem ? root.sectionGrid.headerItem.backButton : null

        function onClicked() {
            root.closeSection();
        }
    }
}
