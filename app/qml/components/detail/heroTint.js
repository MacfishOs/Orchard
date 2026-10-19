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

.pragma library

// Stable page tone from the editorial artwork's background color.
function pageRgb(hex) {
    const match = /^#?([0-9a-f]{6})$/i.exec(String(hex || ""));
    if (!match)
        return null;
    const value = parseInt(match[1], 16);
    const channels = [(value >> 16) & 255, (value >> 8) & 255, value & 255];
    let low = 0;
    let high = 0.72;
    for (let i = 0; i < 12; ++i) {
        const scale = (low + high) / 2;
        const linear = channels.map((channel) => {
            const value = channel / 255 * scale;
            return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
        });
        if (linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722 > 0.14)
            high = scale;
        else
            low = scale;
    }
    return channels.map((channel) => Math.round(channel * low));
}
