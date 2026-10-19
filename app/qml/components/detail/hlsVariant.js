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

// Picks the shortest H.264 SDR variant that still covers minHeight, richest at that height;
// the tallest one when none does.
function pick(master, baseUrl, minHeight) {
    const lines = String(master || "").split(/\r?\n/);
    let best = null;
    for (let i = 0; i < lines.length - 1; ++i) {
        const line = lines[i].trim();
        if (line.indexOf("#EXT-X-STREAM-INF:") !== 0)
            continue;
        const uri = lines[i + 1].trim();
        if (!uri || uri[0] === "#")
            continue;
        const codecs = (/CODECS="([^"]*)"/.exec(line) || [])[1] || "";
        const range = (/VIDEO-RANGE=([A-Z]+)/.exec(line) || [])[1] || "SDR";
        if (codecs.indexOf("avc1") < 0 || range !== "SDR")
            continue;
        const height = Number((/RESOLUTION=\d+x(\d+)/.exec(line) || [])[1] || 0);
        const bandwidth = Number((/[^-]BANDWIDTH=(\d+)/.exec(line) || [])[1] || 0);
        if (!best || better(height, bandwidth, best, minHeight))
            best = { url: resolve(uri, baseUrl), height, bandwidth };
    }
    return best ? best.url : "";
}

function better(height, bandwidth, best, minHeight) {
    const covers = height >= minHeight;
    const bestCovers = best.height >= minHeight;
    if (covers !== bestCovers)
        return covers;
    if (height !== best.height)
        return covers ? height < best.height : height > best.height;
    return bandwidth > best.bandwidth;
}

function resolve(uri, baseUrl) {
    if (/^https?:\/\//.test(uri))
        return uri;
    const base = /^(https?:)\/\/([^/?#]+)(\/[^?#]*)?/.exec(String(baseUrl));
    if (!base)
        return "";
    if (uri.indexOf("//") === 0)
        return base[1] + uri;
    const resource = /^([^?#]*)([?#].*)?$/.exec(uri);
    const path = uri[0] === "/" ? resource[1] : (base[3] || "/").replace(/[^/]*$/, "") + resource[1];
    const parts = [];
    for (const part of path.split("/")) {
        if (part === "..")
            parts.pop();
        else if (part && part !== ".")
            parts.push(part);
    }
    return base[1] + "//" + base[2] + "/" + parts.join("/") + (resource[2] || "");
}

// Apple's byte ranges can all reference one complete MP4. Playing it directly avoids
// FFmpeg restarting at the first range when the HLS segments repeat their MP4 headers.
function mediaSource(playlist, baseUrl) {
    const lines = String(playlist || "").split(/\r?\n/).map((line) => line.trim());
    if (lines.indexOf("#EXT-X-ENDLIST") < 0)
        return baseUrl;
    let file = "";
    let segments = 0;
    for (const line of lines) {
        if (line.indexOf("#EXT-X-KEY:") === 0 && !/(?:^|[:,])METHOD=NONE(?:,|$)/.test(line))
            return baseUrl;
        if (line.indexOf("#EXT-X-MAP:") === 0 || (line && line[0] !== "#")) {
            const uri = line[0] === "#" ? (/URI="([^"]+)"/.exec(line) || [])[1] : line;
            const url = uri ? resolve(uri, baseUrl) : "";
            if (!/\.mp4(?:[?#]|$)/i.test(url) || (file && url !== file))
                return baseUrl;
            file = url;
            if (line[0] !== "#")
                ++segments;
        }
    }
    return segments > 0 ? file : baseUrl;
}
