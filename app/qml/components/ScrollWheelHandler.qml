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

// Reads wheel input as content travel. Wheel notches use angleDelta because
// Wayland also fills pixelDelta for wheels with the compositor's ~15px step.
WheelHandler {
    id: root

    // Pixels per 120-unit notch, three wheel lines by default.
    property real notchPixels: Math.max(1, Application.styleHints.wheelScrollLines) * 60
    property real touchpadGain: 1.75
    // Whole notches in one direction closer than this many ms build boost up to maxBoost.
    property int burstInterval: 350
    property real maxBoost: 2.5

    property real boost: 1
    property real lastNotchTime: 0
    property int lastNotchSign: 0

    target: null
    // Wayland tags every wheel event with the seat's primary device, which is a
    // synthetic touchpad when the compositor offers pointer gestures.
    acceptedDevices: PointerDevice.AllDevices

    // Only finger scrolling carries a phase; device type is unreliable on Wayland.
    function isTouchpad(event) {
        return event.phase !== Qt.NoScrollPhase;
    }

    // Partial notches (hi-res wheels, Windows touchpads) never build boost.
    function burst(angle) {
        if (Math.abs(angle) < 120)
            return 1;
        const now = Date.now();
        const sign = Math.sign(angle);
        if (sign === root.lastNotchSign && now - root.lastNotchTime < root.burstInterval)
            root.boost = Math.min(root.maxBoost, root.boost + 0.25);
        else
            root.boost = 1;
        root.lastNotchTime = now;
        root.lastNotchSign = sign;
        return root.boost;
    }

    // Returns {horizontal, delta, touchpad, smooth}; positive delta scrolls toward the start.
    function measure(event) {
        if (root.isTouchpad(event)) {
            const pixels = event.pixelDelta;
            const sideways = Math.abs(pixels.x) > Math.abs(pixels.y);
            return {
                horizontal: sideways,
                delta: sideways ? pixels.x : pixels.y * root.touchpadGain,
                touchpad: true,
                smooth: false
            };
        }
        const notch = event.angleDelta;
        const horizontal = Math.abs(notch.x) > Math.abs(notch.y);
        const angle = horizontal ? notch.x : notch.y;
        return {
            horizontal: horizontal,
            delta: angle === 0 ? 0 : angle / 120 * root.notchPixels * root.burst(angle),
            touchpad: false,
            smooth: true
        };
    }
}
