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

// Apple Music resource ids carried as Orchard browse ids: am.<type>.<id>.
// Apple ids may contain dots (pl.u-...), so only the first two separate.

export const APPLE_MUSIC_SOURCE = 'apple_music';
const PREFIX = 'am.';

export function browseId(type, id) {
  return id ? `${PREFIX}${type}.${id}` : '';
}

/** {type, id} for an Orchard browse id, or null when it is not an Apple Music id. */
export function parseBrowseId(value) {
  const text = String(value || '');
  if (!text.startsWith(PREFIX)) return null;
  const rest = text.slice(PREFIX.length);
  const separator = rest.indexOf('.');
  if (separator <= 0 || separator === rest.length - 1) return null;
  return { type: rest.slice(0, separator), id: rest.slice(separator + 1) };
}

export function isAppleMusicId(value) {
  return parseBrowseId(value) !== null;
}
