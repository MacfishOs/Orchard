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

// Saves the visited page and hands it back after session restoration. Stored with the queue, so it follows the same switch.
QtObject {
    id: root

    property string page: ""
    property var item: ({
    })
    property string query: ""
    property string filter: "all"
    // Saves stay off until the stored page is read, so the startup home page can't overwrite it.
    property bool restored: false
    readonly property bool sessionsReady: OrchardAuth.isSignedIn
                                          && (OrchardHome.homeSource !== "apple_music"
                                              || OrchardAppleMusic.status !== "restoring")

    signal restoreRequested(var saved)

    function restore() {
        if (restored || !sessionsReady)
            return ;
        restored = true;
        const saved = OrchardPlayback.restoredPage();
        if (saved.page)
            restoreRequested(saved);
    }

    function schedule() {
        if (restored)
            saveTimer.restart();
    }

    onPageChanged: schedule()
    onItemChanged: schedule()
    onQueryChanged: schedule()
    onFilterChanged: schedule()
    // Deferred because the controllers clear themselves on the sessionChanged that follows sign-in.
    onSessionsReadyChanged: Qt.callLater(root.restore)
    Component.onCompleted: Qt.callLater(root.restore)

    // Coalesce typing and rapid navigation into one write.
    property Timer saveTimer: Timer {
        interval: 300
        onTriggered: OrchardPlayback.savePage({
            "page": root.page,
            "item": root.item,
            "query": root.query,
            "filter": root.filter
        })
    }
}
