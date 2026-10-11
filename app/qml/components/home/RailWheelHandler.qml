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

// Routes wheel input for a horizontal rail: sideways deltas scroll the rail,
// vertical ones go back to the containing page.
ScrollWheelHandler {
    id: root

    signal verticalRequested(real delta, bool smooth)
    signal horizontalRequested(real delta, bool smooth)

    onWheel: function (event) {
        const motion = root.measure(event);
        event.accepted = true;
        if (motion.horizontal !== (root.orientation === Qt.Horizontal))
            return;
        // Trackpads often add a small sideways delta to vertical gestures; those go to the page.
        if (!motion.horizontal) {
            root.verticalRequested(motion.delta, motion.smooth);
            return;
        }
        root.horizontalRequested(motion.touchpad ? motion.delta : motion.delta / 2, motion.smooth);
    }
}
