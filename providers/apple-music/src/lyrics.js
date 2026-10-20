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

// Apple Music's own time-synced lyrics as TTML; hosts parse it with the other lyric sources.

import { AppleMusicError } from './client.js';
import { findSong } from './match.js';

// Word-by-word first; songs with only line timing answer 404 there.
const KINDS = ['syllable-lyrics', 'lyrics'];

function missing(error) {
  if (error instanceof AppleMusicError && error.code === 'not_found') return null;
  throw error;
}

export function createLyricsCatalog(client) {
  /** {songId, ttml} for a track from any service, or null when Apple has no lyrics for it. */
  async function lyrics(query = {}) {
    const song = await findSong(client, query);
    if (!song?.id || song.attributes?.hasLyrics === false) return null;
    const path = `/v1/catalog/${client.storefront()}/songs/${encodeURIComponent(song.id)}`;
    for (const kind of KINDS) {
      const result = await client.editorial(`${path}/${kind}`, {}, { personal: true }).catch(missing);
      const ttml = result?.data?.[0]?.attributes?.ttml;
      if (ttml) return { songId: song.id, ttml };
    }
    return null;
  }

  return { lyrics };
}
