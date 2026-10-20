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

// Settings window shell and transitions. The panel lives in SettingsPanel.ui.qml.
Popup {
    id: root
    // Docs live in their own popup; the shell closes this one and opens it.
    signal docsRequested
    // Same deal for bug reports: the shell swaps this popup for the report one.
    signal supportRequested
    // Release notes live in their own popup too.
    signal releaseNotesRequested
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(1180, parent.width - 48)
    height: Math.min(820, parent.height - 48)
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle {
        color: "#73000000"
        Behavior on opacity { NumberAnimation { duration: Motion.normal } }
    }

    function matches(entry, query) {
        const needle = String(query || "").trim().toLowerCase();
        if (needle.length === 0)
            return true;
        const haystack = (entry.label + " " + entry.blurb + " " + (entry.keywords || "")).toLowerCase();
        return needle.split(/\s+/).every(word => haystack.indexOf(word) >= 0);
    }

    function firstMatch(query) {
        for (let i = 0; i < panel.sections.length; i++) {
            if (matches(panel.sections[i], query))
                return i;
        }
        return -1;
    }

    onClosed: panel.searchField.text = ""

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: 380; easing.type: Easing.OutQuint }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 160; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.97; duration: 160; easing.type: Easing.InCubic }
        }
    }

    background: Rectangle {
        radius: 12
        color: OrchardAppearance.popupColor
        border.color: "#1fffffff"
        border.width: 1
        Behavior on color { ColorAnimation { duration: Motion.slow } }
    }

    contentItem: SettingsPanel {
        id: panel

        matchCount: {
            let count = 0;
            for (const entry of sections) {
                if (root.matches(entry, searchField.text))
                    count++;
            }
            return count;
        }

        docsLink.onClicked: root.docsRequested()
        supportLink.onClicked: root.supportRequested()
        closeButton.onClicked: root.close()
        profileButton.onClicked: panel.currentIndex = 0

        searchField.onTextChanged: {
            const index = root.firstMatch(searchField.text);
            if (index >= 0 && !root.matches(sections[currentIndex], searchField.text))
                currentIndex = index;
        }
        searchField.onAccepted: {
            const index = root.firstMatch(searchField.text);
            if (index >= 0)
                currentIndex = index;
        }
        navList.delegate: SettingsNavItem {
            required property var modelData
            required property int index
            // The Repeater parents delegates to the sidebar column; panel.width would span the whole popup.
            width: parent ? parent.width : 0
            entry: modelData
            current: panel.currentIndex === index
            visible: root.matches(modelData, panel.searchField.text)
            onClicked: panel.currentIndex = index
        }

        // Cards animate themselves in; start each section from the top and ease the header in.
        sectionLoader.onLoaded: {
            panel.scroller.contentItem.contentY = 0;
            panel.headerFade.restart();
            headerIn.restart();
        }

        NumberAnimation {
            id: headerIn
            target: panel.headerSlide
            property: "x"
            from: -12
            to: 0
            duration: 380
            easing.type: Easing.OutQuint
        }

        Connections {
            target: panel.sectionLoader.item
            ignoreUnknownSignals: true

            function onReleaseNotesRequested() {
                root.releaseNotesRequested();
            }

            function onSignOutRequested() {
                root.close();
                OrchardAuth.signOut();
            }
        }
    }
}
