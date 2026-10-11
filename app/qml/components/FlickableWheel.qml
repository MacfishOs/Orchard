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
import QtQuick.Controls

// Momentum wheel scrolling for a vertical Flickable. Declare it inside the view
// (or a ScrollView) so it sees wheel events before the Flickable does.
ScrollWheelHandler {
    id: root

    // Item so a ScrollView's contentItem binds without a cast at the call site.
    required property Item view
    readonly property Flickable flickable: root.view as Flickable
    readonly property WheelGlide glide: WheelGlide {
        view: root.flickable
    }
    readonly property Connections stopper: Connections {
        target: root.flickable
        function onDraggingChanged() {
            if (root.flickable.dragging)
                root.glide.stop();
        }
        function onVisibleChanged() {
            root.glide.stop();
        }
    }
    readonly property Connections barStopper: Connections {
        target: root.flickable ? root.flickable.ScrollBar.vertical : null
        ignoreUnknownSignals: true
        function onPressedChanged() {
            root.glide.stop();
        }
    }

    onWheel: function(event) {
        const motion = root.measure(event);
        if (motion.horizontal || !root.flickable) {
            event.accepted = false;
            return;
        }
        root.glide.scrollBy(motion.delta, motion.smooth);
        event.accepted = true;
    }
}
