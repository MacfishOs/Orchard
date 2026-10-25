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
import "../album"
import "../artist"
import "../library"
import "../offline"
import "../playlist"
import "../search"
import "../../components/detail/heroTint.js" as HeroTint
import Orchard
import QtQuick
import QtQuick.Window

// Backdrop, sidebar, top bar and pages of the signed-in shell. Navigation state lives in HomeShell.
Item {
    id: scene

    // HomeShell: owns navigation, history and overlays.
    required property Item shell
    // Bottom inset that keeps page content clear of the floating player.
    property real dockHeight: 0
    property real sidebarWidth: width < 1100 ? 76 : 218
    readonly property real queueWidth: Math.round(Math.min(380, Math.max(320, width * 0.26)))
    readonly property alias immersive: immersive
    readonly property alias home: home
    readonly property alias topBar: topBar
    readonly property alias sidebar: sidebar
    readonly property alias offlineHomeLoader: offlineHomeLoader
    readonly property alias libraryLoader: libraryLoader
    readonly property alias searchLoader: searchLoader
    readonly property alias albumLoader: albumLoader
    readonly property alias artistLoader: artistLoader
    readonly property alias playlistLoader: playlistLoader
    readonly property alias playerDock: playerDock
    // Apple's hero tint holds the shell from the first frame, ahead of the song's artwork background.
    // Cutefish OS Color Palette (Light & Dark mode support)
    readonly property bool isDarkMode: true
    readonly property color cutefishBg: isDarkMode ? "#1C1C1F" : "#F5F6FA"
    readonly property color cutefishSidebarBg: isDarkMode ? Qt.rgba(0.14, 0.14, 0.16, 0.86) : Qt.rgba(0.95, 0.95, 0.97, 0.90)
    readonly property color cutefishContainerBg: isDarkMode ? "#2C2C2D" : "#FFFFFF"
    readonly property color cutefishText: isDarkMode ? "#FFFFFF" : "#323238"
    readonly property color cutefishSecondaryText: isDarkMode ? "#888888" : "#64646E"
    readonly property color cutefishSeam: isDarkMode ? "#2D2D31" : "#E2E4EA"
    readonly property color cutefishAccent: "#2A7AF6"

    readonly property bool artistTinted: scene.shell.currentPage === "artist" && !!HeroTint.pageRgb((OrchardArtist.detail || {}).heroTint)
    readonly property color collectionDeep: {
        if (scene.shell.currentPage === "artist")
            return scene.paletteColor(HeroTint.pageRgb((OrchardArtist.detail || {}).heroTint) || (OrchardArtist.palette || {}).deep, [15, 21, 18]);
        if (scene.shell.currentPage === "playlist")
            return scene.paletteColor((OrchardPlaylist.palette || {}).deep, [15, 21, 18]);
        return scene.paletteColor((OrchardAlbum.palette || {}).deep, [15, 21, 18]);
    }
    readonly property color collectionInk: scene.shell.currentPage === "artist"
        ? scene.collectionDeep
        : scene.paletteColor(scene.shell.currentPage === "playlist"
            ? (OrchardPlaylist.palette || {}).ink
            : (OrchardAlbum.palette || {}).ink, [8, 12, 10])
    readonly property color collectionSeam: scene.shell.currentPage === "artist"
        ? scene.collectionDeep
        : scene.paletteColor(scene.shell.currentPage === "playlist"
            ? (OrchardPlaylist.palette || {}).seam
            : (OrchardAlbum.palette || {}).seam, [38, 48, 43])

    function paletteColor(value, fallback) {
        const color = value && value.length >= 3 ? value : fallback;
        return Qt.rgba(Number(color[0]) / 255, Number(color[1]) / 255, Number(color[2]) / 255, 1);
    }

    function tint(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function detailThumbnail() {
        if (scene.shell.currentPage === "album")
            return (OrchardAlbum.detail || {}).thumbnail || "";
        if (scene.shell.currentPage === "playlist")
            return (OrchardPlaylist.detail || {}).thumbnail || "";
        return "";
    }

    anchors.fill: parent
    visible: !scene.shell.fullscreenCovering
    // Pages, pill and sidebar all follow this, so they slide together on compact toggles.
    Behavior on sidebarWidth {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.enter }
    }
    // Render the page once into a texture that every glass panel samples directly, instead of
    // each panel re-rendering the whole page into its own capture. Frames where only the player
    // bar changes (the progress ticker) also skip redrawing the page. Draw once, blur everywhere.
    layer.enabled: true

    // Cutefish OS main window background
    Rectangle {
        anchors.fill: parent
        color: scene.cutefishBg
        z: -2
    }

    // Immersive background artwork underneath
    ImmersiveBackground {
        id: immersive
        anchors.fill: parent
        source: OrchardAppearance.immersiveBackground ? (OrchardPlayback.track.thumbnail || scene.detailThumbnail()) : ""
        visible: OrchardAppearance.immersiveBackground
        throttled: OrchardWindowState.backgroundIdle
        running: scene.shell.visible && visible && !videoAmbient.covering && OrchardPlayback.playing && scene.Window.window !== null && scene.Window.window.visibility !== Window.Minimized && scene.Window.window.visibility !== Window.Hidden
        speed: OrchardAppearance.speed
        intensity: OrchardAppearance.intensity
        saturation: OrchardAppearance.saturation
        brightness: OrchardAppearance.brightness
    }

    // Cutefish OS native sidebar background (#232326 in dark mode)
    Rectangle {
        id: sidebarBg
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: scene.sidebarWidth
        color: scene.cutefishSidebarBg
    }

    // Line separator for the sidebar right edge (Cutefish thin seam)
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: scene.sidebarWidth - 1
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: scene.cutefishSeam
    }

    // Video samples fill pages without an editorial background color.
    VideoAmbient {
        id: videoAmbient

        readonly property bool covering: opacity === 1

        anchors.fill: parent
        colors: OrchardArtistVideo.ambient
        opacity: scene.shell.currentPage === "artist" && !scene.artistTinted && OrchardAppearance.artistVideoBackdrop && ready ? 1 : 0
        visible: opacity > 0 && !scene.artistTinted
        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
    }

    // Open pages and their history belong to the previous service; search reruns on its own.
    Connections {
        function onHomeSourceChanged() {
            if (scene.shell.currentPage !== "search")
                scene.shell.navigateTo("home");
        }

        target: OrchardHome
    }

    NavigationSidebar {
        id: sidebar

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: scene.sidebarWidth
        compact: scene.width < 1100
        currentPage: scene.shell.currentPage
        onSpotlightRequested: scene.shell.openSpotlight(query)
        onSearchChanged: function(query) {
            scene.shell.searchQuery = query;
            if (query.trim()) {
                if (scene.shell.currentPage !== "search") {
                    scene.shell.history = [];
                    scene.shell.currentItem = ({});
                    scene.shell.currentPage = "search";
                }
                OrchardSearch.clear();
                scene.shell.searchDebounce.restart();
            } else {
                scene.shell.searchDebounce.stop();
                OrchardSearch.clear();
            }
        }
        onPageRequested: function(page) {
            scene.shell.navigateTo(page);
        }
        onPlaylistRequested: function(playlist) {
            scene.shell.openDetail("playlist", playlist);
        }
    }

    HomeView {
        id: home

        anchors.left: parent.left
        anchors.leftMargin: scene.sidebarWidth + 28
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        visible: scene.shell.currentPage === "home" && !OrchardNetwork.offline
        onArtistRequested: function(artist) {
            scene.shell.openDetail("artist", artist);
        }
        onUnsupportedRequested: function(media) {
            OrchardMusicVideo.playVideo(media);
        }
        onAlbumRequested: function(album) {
            scene.shell.openDetail("album", album);
        }
        onPlaylistRequested: function(playlist) {
            scene.shell.openDetail("playlist", playlist);
        }
    }

    Loader {
        id: offlineHomeLoader
        anchors.fill: home
        active: scene.shell.currentPage === "home" && OrchardNetwork.offline

        sourceComponent: Component {
            OfflineHomeView {
                onPlaylistRequested: function(playlist) {
                    scene.shell.openDetail("playlist", playlist);
                }
            }
        }
    }

    Loader {
        id: libraryLoader
        anchors.fill: home
        active: scene.shell.currentPage === "library"
        sourceComponent: OrchardNetwork.offline ? offlineLibraryComponent : onlineLibraryComponent
    }

    Component {
        id: offlineLibraryComponent

        OfflineLibraryView {
            onPlaylistRequested: function(playlist) {
                scene.shell.openDetail("playlist", playlist);
            }
        }
    }

    Component {
        id: onlineLibraryComponent

        LibraryView {
            onArtistRequested: function(artist) {
                scene.shell.openDetail("artist", artist);
            }
            onAlbumRequested: function(album) {
                scene.shell.openDetail("album", album);
            }
            onPlaylistRequested: function(playlist) {
                scene.shell.openDetail("playlist", playlist);
            }
            onUnsupportedRequested: function(media) {
                OrchardMusicVideo.playVideo(media);
            }
        }
    }

    Loader {
        id: searchLoader
        anchors.left: home.left
        anchors.right: home.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        active: scene.shell.currentPage === "search"

        sourceComponent: Component {
            SearchView {
                query: scene.shell.searchQuery
                filter: scene.shell.searchFilter
                sections: OrchardSearch.sections
                loading: OrchardSearch.loading
                errorMessage: OrchardSearch.errorMessage
                onFilterRequested: function(filter) {
                    scene.shell.searchFilter = filter;
                    OrchardSearch.clear();
                    if (scene.shell.searchQuery.trim())
                        scene.shell.searchDebounce.restart();
                }
                onRetryRequested: OrchardSearch.retry()
                onSongRequested: function(song) {
                    const sections = OrchardSearch.sections || [];
                    const tracks = [];
                    // Qt lists skipped the flatMap orientation. Copy their items explicitly.
                    for (let sectionIndex = 0; sectionIndex < sections.length; ++sectionIndex) {
                        const items = sections[sectionIndex].items || [];
                        for (let itemIndex = 0; itemIndex < items.length; ++itemIndex) tracks.push(items[itemIndex])
                    }
                    const index = tracks.findIndex((track) => {
                        return track.id === song.id;
                    });
                    if (index >= 0)
                        OrchardPlayback.playCollection(tracks, index);
                    else
                        OrchardPlayback.playSong(song);
                }
                onUnsupportedRequested: function(media) {
                    OrchardMusicVideo.playVideo(media);
                }
                onAlbumRequested: function(album) {
                    scene.shell.openDetail("album", album);
                }
                onArtistRequested: function(artist) {
                    scene.shell.openDetail("artist", artist);
                }
                onPlaylistRequested: function(playlist) {
                    scene.shell.openDetail("playlist", playlist);
                }
            }
        }
    }

    AppTopBar {
        id: topBar

        anchors.left: home.left
        anchors.right: home.right
        anchors.top: parent.top
        anchors.topMargin: 32
        height: 62
        // Floats over the artist page, which runs under it.
        z: 1
        onSettingsRequested: scene.shell.openSettings()
    }

    Loader {
        id: albumLoader
        anchors.left: home.left
        anchors.right: home.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        active: scene.shell.currentPage === "album"

        sourceComponent: Component {
            AlbumView {
                sharedBackground: true
                onBackRequested: scene.shell.goBack()
                onAlbumRequested: function(album) {
                    scene.shell.openDetail("album", album);
                }
                onArtistRequested: function(artist) {
                    scene.shell.openDetail("artist", artist);
                }
                onPlaylistRequested: function(playlist) {
                    scene.shell.openDetail("playlist", playlist);
                }
                // Album origin lets playback keep an in-order playthrough gapless.
                function albumTracks() {
                    const detail = OrchardAlbum.detail || {};
                    const origin = { kind: "album", title: detail.title || "", artist: detail.artist || "" };
                    return (detail.tracks || []).map((item) => Object.assign({}, item, { queueOrigin: origin }));
                }
                onPlayRequested: OrchardPlayback.playCollection(albumTracks(), 0, false)
                onShuffleRequested: OrchardPlayback.playCollection(albumTracks(), 0, true)
                onTrackRequested: function(track, index) {
                    const tracks = albumTracks();
                    const selectedIndex = tracks.findIndex((item) => {
                        return item.id === track.id;
                    });
                    if (selectedIndex >= 0)
                        OrchardPlayback.playCollection(tracks, selectedIndex, false);
                }
            }
        }
    }

    Loader {
        id: artistLoader
        anchors.left: parent.left
        anchors.leftMargin: scene.sidebarWidth
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        active: scene.shell.currentPage === "artist"

        sourceComponent: Component {
            ArtistView {
                sharedBackground: true
                topInset: topBar.y + topBar.height
                edgeInset: 28
                onBackRequested: scene.shell.goBack()
                onAlbumRequested: function(album) {
                    scene.shell.openDetail("album", album);
                }
                onArtistRequested: function(artist) {
                    scene.shell.openDetail("artist", artist);
                }
                onPlaylistRequested: function(playlist) {
                    scene.shell.openDetail("playlist", playlist);
                }
                onUnsupportedRequested: function(media) {
                    OrchardMusicVideo.playVideo(media);
                }
            }
        }
    }

    Loader {
        id: playlistLoader
        anchors.left: home.left
        anchors.right: home.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        active: scene.shell.currentPage === "playlist"

        sourceComponent: Component {
            PlaylistView {
                sharedBackground: true
                onBackRequested: scene.shell.goBack()
                onAlbumRequested: function(album) {
                    scene.shell.openDetail("album", album);
                }
                onArtistRequested: function(artist) {
                    scene.shell.openDetail("artist", artist);
                }
                onPlaylistRequested: function(playlist) {
                    scene.shell.openDetail("playlist", playlist);
                }
                onPlayRequested: scene.shell.playPlaylist(0, false)
                onShuffleRequested: scene.shell.playPlaylist(0, true)
                onTrackRequested: function(track, index) {
                    scene.shell.playPlaylist(index, false);
                }
            }
        }
    }

    // Pages scroll beneath the floating player; this is the inset they pad by.
    Item {
        id: playerDock

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: scene.dockHeight
    }
}
