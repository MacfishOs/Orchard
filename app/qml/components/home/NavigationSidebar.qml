/*
 * Copyright (C) 2026 Cutefish / Orchard
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import ".."
import Orchard
import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string currentPage: "home"
    property string currentLibraryFilter: "all"
    property bool compact: false
    property alias query: sidebarSearch.query
    // Labels fade with the width animation; clip keeps them inside while it runs.
    property real labelOpacity: compact ? 0 : 1

    signal pageRequested(string page, string filter)
    signal playlistRequested(var playlist)
    signal searchChanged(string query)
    signal spotlightRequested

    function focusSearch() { sidebarSearch.focusSearch(); }
    function clearSearch() { sidebarSearch.clearSearch(); }

    clip: true

    Behavior on labelOpacity {
        NumberAnimation { duration: Motion.normal; easing.type: Motion.enter }
    }

    Column {
        id: mainColumn

        anchors.top: parent.top
        anchors.topMargin: 30
        anchors.left: parent.left
        anchors.leftMargin: root.compact ? 12 : 16
        anchors.right: parent.right
        anchors.rightMargin: root.compact ? 12 : 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 6

        // Apple Music Style Logo & Title Header
        Row {
            height: 48
            spacing: 10

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                source: "../../assets/orchard-logo.png"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.labelOpacity
                visible: opacity > 0
                text: qsTr("Music")
                color: "#f5f3ee"
                font.family: "SF Pro Display, SF Pro, Inter, sans-serif"
                font.pixelSize: 20
                font.weight: Font.Bold
                font.letterSpacing: -0.4
            }
        }

        // Search Bar
        SidebarSearch {
            id: sidebarSearch

            width: root.compact ? 34 : parent.width
            x: (parent.width - width) / 2
            compact: root.compact
            onSearchChanged: function(query) { root.searchChanged(query); }
            onSpotlightRequested: root.spotlightRequested()
        }

        Item { width: 1; height: 4 }

        // Top Navigation (Listen Now / Browse / Radio)
        Repeater {
            model: [
                { key: "home", title: qsTr("Listen Now"), icon: "play", filter: "" },
                { key: "home", title: qsTr("Browse"), icon: "compass", filter: "" },
                { key: "search", title: qsTr("Search"), icon: "search", filter: "" }
            ]

            Button {
                id: topNav

                required property var modelData
                readonly property bool active: (modelData.key === "home" && modelData.title === qsTr("Listen Now") && root.currentPage === "home")
                                            || (modelData.key === "search" && root.currentPage === "search")

                width: parent.width
                height: 34
                onClicked: {
                    if (modelData.key === "search") {
                        root.focusSearch();
                    }
                    root.pageRequested(modelData.key, modelData.filter);
                }
                ToolTip.visible: root.visible && root.enabled && hovered
                ToolTip.text: modelData.title

                background: Rectangle {
                    radius: 8
                    color: topNav.active ? "#36363b" : topNav.hovered ? "#14ffffff" : "transparent"
                    border.color: topNav.activeFocus ? OrchardAppearance.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                contentItem: Row {
                    spacing: 11
                    leftPadding: root.compact ? (parent.width - 17) / 2 : 8

                    LucideIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 17
                        height: 17
                        name: topNav.modelData.icon
                        color: topNav.active ? OrchardAppearance.accent : "#c1c7ca"
                        Behavior on color { ColorAnimation { duration: Motion.normal } }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.labelOpacity
                        visible: opacity > 0
                        text: topNav.modelData.title
                        color: topNav.active ? "#ffffff" : "#d3d8da"
                        font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                        font.pixelSize: 13
                        font.weight: topNav.active ? Font.DemiBold : Font.Normal
                        Behavior on color { ColorAnimation { duration: Motion.normal } }
                    }
                }
            }
        }

        // Section: LIBRARY
        Text {
            topPadding: 14
            bottomPadding: 4
            leftPadding: 8
            visible: !root.compact
            text: qsTr("LIBRARY")
            font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: "#8e8e93"
        }

        Repeater {
            model: [
                { key: "library", title: qsTr("Recently Added"), icon: "sparkles", filter: "all" },
                { key: "library", title: qsTr("Artists"), icon: "circle-user-round", filter: "artists" },
                { key: "library", title: qsTr("Albums"), icon: "library-big", filter: "albums" },
                { key: "library", title: qsTr("Songs"), icon: "music-2", filter: "songs" }
            ]

            Button {
                id: libNav

                required property var modelData
                readonly property bool active: root.currentPage === "library" && root.currentLibraryFilter === modelData.filter

                width: parent.width
                height: 34
                onClicked: {
                    root.currentLibraryFilter = modelData.filter;
                    root.pageRequested("library", modelData.filter);
                }
                ToolTip.visible: root.visible && root.enabled && hovered
                ToolTip.text: modelData.title

                background: Rectangle {
                    radius: 8
                    color: libNav.active ? "#36363b" : libNav.hovered ? "#14ffffff" : "transparent"
                    border.color: libNav.activeFocus ? OrchardAppearance.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                contentItem: Row {
                    spacing: 11
                    leftPadding: root.compact ? (parent.width - 17) / 2 : 8

                    LucideIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 17
                        height: 17
                        name: libNav.modelData.icon
                        color: libNav.active ? OrchardAppearance.accent : "#c1c7ca"
                        Behavior on color { ColorAnimation { duration: Motion.normal } }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.labelOpacity
                        visible: opacity > 0
                        text: libNav.modelData.title
                        color: libNav.active ? "#ffffff" : "#d3d8da"
                        font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                        font.pixelSize: 13
                        font.weight: libNav.active ? Font.DemiBold : Font.Normal
                        Behavior on color { ColorAnimation { duration: Motion.normal } }
                    }
                }
            }
        }

        // Section: PLAYLISTS
        Text {
            topPadding: 14
            bottomPadding: 4
            leftPadding: 8
            visible: !root.compact
            text: qsTr("PLAYLISTS")
            font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: "#8e8e93"
        }

        // New Playlist Button
        Button {
            id: newPlaylistButton

            width: parent.width
            height: 32
            onClicked: newPlaylistDialog.createObject(Overlay.overlay).open()
            ToolTip.visible: root.visible && root.enabled && hovered
            ToolTip.text: qsTr("New Playlist")
            Accessible.name: qsTr("New Playlist")

            background: Rectangle {
                radius: 7
                color: newPlaylistButton.hovered ? "#18ffffff" : "#0cffffff"
                border.color: newPlaylistButton.activeFocus ? OrchardAppearance.accent : "#18ffffff"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            contentItem: Row {
                spacing: 9
                leftPadding: root.compact ? (parent.width - 15) / 2 : 8

                LucideIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    name: "plus"
                    color: "#c1c7ca"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.labelOpacity
                    visible: opacity > 0
                    text: qsTr("New Playlist")
                    color: "#d3d8da"
                    font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        Component {
            id: newPlaylistDialog
            NewPlaylistDialog {}
        }

        // Playlist List
        ListView {
            id: playlistList

            width: parent.width
            height: Math.max(0, mainColumn.height - y)
            clip: true
            spacing: 2
            model: OrchardNetwork.offline ? OrchardOffline.playlists
                : (OrchardLocal.playlists || []).concat((OrchardHome.playlists || []).filter((p) => {
                    return p.title !== "New playlist";
                }))

            ScrollBar.vertical: ScrollBar {
                width: 3
            }

            delegate: Button {
                id: shortcut

                required property var modelData
                readonly property bool isLocal: modelData.source === "local" || modelData.source === "download"

                width: ListView.view.width
                height: 34
                onClicked: root.playlistRequested(shortcut.modelData)
                ToolTip.visible: root.visible && root.enabled && hovered
                ToolTip.text: modelData.title || ""

                background: Rectangle {
                    radius: 7
                    color: shortcut.hovered ? "#12ffffff" : "transparent"
                    border.color: shortcut.activeFocus ? OrchardAppearance.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                contentItem: Row {
                    spacing: 9
                    leftPadding: root.compact ? (parent.width - 24) / 2 : 6

                    RoundedArtwork {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 5
                        source: shortcut.modelData.thumbnail || ""
                    }

                    Text {
                        width: shortcut.width - 50 - (shortcut.isLocal ? 18 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.labelOpacity
                        visible: opacity > 0
                        text: shortcut.modelData.title || ""
                        color: "#d3d8da"
                        font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    LucideIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: shortcut.isLocal && root.labelOpacity > 0
                        opacity: root.labelOpacity
                        width: 11
                        height: 11
                        name: shortcut.modelData.source === "download" ? "download" : "hard-drive"
                        color: "#7f898d"
                    }
                }
            }

            footer: Text {
                width: parent.width
                visible: !root.compact && playlistList.count === 0
                text: OrchardNetwork.offline ? qsTr("Downloaded playlists will appear here.")
                    : OrchardHome.playlistsLoading ? qsTr("Loading playlists…") : OrchardHome.playlistsError || qsTr("Your saved playlists will appear here.")
                wrapMode: Text.Wrap
                color: "#8e8e93"
                font.family: "SF Pro Text, SF Pro, Inter, sans-serif"
                font.pixelSize: 11
                leftPadding: 8
            }

            FlickableWheel {
                view: playlistList
            }
        }
    }
}
