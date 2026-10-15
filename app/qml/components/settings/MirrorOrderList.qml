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

// Reorderable list of motion-artwork mirrors, tried top to bottom.
MirrorOrderListForm {
    id: root

    // Signed in to Apple Music, m8tec and boidu collapse into one Apple row that moves as a unit.
    readonly property bool apple: OrchardAppleMusic.connected
    readonly property var rows: {
        const order = OrchardAppearance.availableMirrors;
        if (!apple)
            return order.map(mirror => ({ name: mirror.name, host: mirror.host, ids: [mirror.id] }));
        const unofficial = order.filter(mirror => mirror.id !== "spotify").map(mirror => mirror.id);
        const result = [];
        for (const mirror of order) {
            if (mirror.id === "spotify")
                result.push({ name: mirror.name, host: mirror.host, ids: [mirror.id] });
            else if (mirror.id === unofficial[0])
                result.push({ name: qsTr("Apple Music"), host: "api.music.apple.com", ids: unofficial });
        }
        return result;
    }

    function move(from, to) {
        const reordered = rows.slice();
        const moved = reordered.splice(from, 1)[0];
        reordered.splice(to, 0, moved);
        OrchardAppearance.mirrorOrder = reordered.reduce((ids, row) => ids.concat(row.ids), []);
    }

    mirrors: rows

    mirrorList.delegate: MirrorOrderRow {
        required property var modelData
        required property int index
        position: index
        name: modelData.name || ""
        host: modelData.host || ""
        canMoveUp: index > 0
        canMoveDown: index < root.rows.length - 1
        upButton.area.onClicked: root.move(index, index - 1)
        downButton.area.onClicked: root.move(index, index + 1)
    }
}
