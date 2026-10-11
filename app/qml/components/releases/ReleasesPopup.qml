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


import QtQuick
import ".."

// Release notes in their own window, one release at a time.
GlassPopup {
    id: root

    // Version to open on; empty shows the installed build.
    property string release: ""

    width: Math.min(1080, parent.width - 64)
    height: Math.min(720, parent.height - 64)

    onOpened: view.focusSearch()

    contentItem: ReleasesView {
        id: view
        initialRelease: root.release
        onCloseRequested: root.close()
    }
}
