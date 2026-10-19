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

import { browseId, parseBrowseId } from './ids.js';
import { artworkUrl } from './normalize.js';

const CANDIDATES = 10;

function normalized(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/** Drops "(feat. X)", "[Deluxe]" and " - Single" so YouTube and Apple spellings meet. */
function editionless(value) {
  const stripped = String(value || '')
    .replace(/\s*[([][^)\]]*[)\]]/g, '')
    .replace(/\s+-\s+[^-]*\b(single|ep|deluxe|edition|version|remaster(ed)?|expanded|anniversary|bonus)\b.*$/i, '');
  return normalized(stripped) || normalized(value);
}

function sameTitle(left, right) {
  const a = editionless(left);
  return a !== '' && a === editionless(right);
}

function sameArtist(left, right) {
  const a = normalized(left);
  const b = normalized(right);
  return a !== '' && b !== '' && (a === b || a.includes(b) || b.includes(a));
}

/** Search results carry no relationships; the album id is in the song's web URL. */
function albumIdOf(song) {
  const fromRelationship = song?.relationships?.albums?.data?.[0]?.id;
  if (fromRelationship) return fromRelationship;
  return /\/album\/[^/]+\/(\d+)/.exec(String(song?.attributes?.url || ''))?.[1] || '';
}

function pickSong(songs, { title, artist, album }) {
  const matches = songs.filter((song) =>
    sameTitle(song.attributes?.name, title) && sameArtist(song.attributes?.artistName, artist));
  return matches.find((song) => album && sameTitle(song.attributes?.albumName, album)) || matches[0] || null;
}

export function createArtworkCatalog(client) {
  const path = (type, id = '') => `/v1/catalog/${client.storefront()}/${type}${id ? `/${encodeURIComponent(id)}` : ''}`;

  async function albumArtwork(id) {
    // Only music.apple.com's API returns editorialVideo; the public one still has the cover.
    const result = (await client.editorial(path('albums', id), { extend: 'editorialVideo' }))
      || await client.get(path('albums', id));
    const resource = result.data?.[0];
    const attributes = resource?.attributes;
    if (!attributes) return null;
    const video = attributes.editorialVideo || {};
    return {
      albumId: browseId('albums', resource.id),
      name: attributes.name || '',
      artist: attributes.artistName || '',
      static: artworkUrl(attributes.artwork, 1200),
      animated: video.motionDetailSquare?.video || '',
      animatedVertical: video.motionDetailTall?.video || ''
    };
  }

  async function songAlbumId({ appleId, isrc, title, artist, album }) {
    if (appleId) {
      const song = (await client.get(path('songs', appleId))).data?.[0];
      return albumIdOf(song);
    }
    if (isrc) {
      const songs = (await client.get(path('songs'), { 'filter[isrc]': isrc })).data || [];
      const id = albumIdOf(pickSong(songs, { title, artist, album }) || songs[0]);
      if (id) return id;
    }
    if (!title || !artist) return '';
    const result = await client.get(path('search'), { term: `${title} ${artist}`, types: 'songs', limit: CANDIDATES });
    return albumIdOf(pickSong(result.results?.songs?.data || [], { title, artist, album }));
  }

  async function albumIdByName(name, artist) {
    if (!name || !artist) return '';
    const result = await client.get(path('search'), { term: `${name} ${artist}`, types: 'albums', limit: CANDIDATES });
    const albums = result.results?.albums?.data || [];
    const match = albums.find((album) =>
      sameTitle(album.attributes?.name, name) && sameArtist(album.attributes?.artistName, artist));
    return match?.id || '';
  }

  /**
   * Apple's motion artwork for a song or album: square and tall HLS URLs plus the still cover.
   * Accepts an am.albums id, an Apple song id, an ISRC, or plain title/artist/album text.
   */
  async function artwork(query = {}) {
    const parsed = parseBrowseId(query.albumId);
    let id = parsed?.type === 'albums' ? parsed.id : '';
    if (!id && query.kind === 'album') id = await albumIdByName(query.album || query.title, query.artist);
    if (!id) id = await songAlbumId(query);
    return id ? albumArtwork(id) : null;
  }

  return { artwork };
}
