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

export const WEB_ORIGIN = 'https://music.apple.com';
const ENTRY = /\/assets\/index[^"']*\.js/;
const JWT = /eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/;
const RETRY_MS = 10 * 60 * 1000;

/**
 * music.apple.com's developer token, read from its main bundle. Only this token carries the
 * editorial permissions (editorialVideo, editorialArtwork) that third-party tokens lack.
 */
export function createWebToken(fetchImpl) {
  let pending = null;

  async function load() {
    const page = await fetchImpl(`${WEB_ORIGIN}/us/new`);
    if (!page.ok) return '';
    const entry = ENTRY.exec(await page.text())?.[0];
    if (!entry) return '';
    const bundle = await fetchImpl(`${WEB_ORIGIN}${entry}`);
    if (!bundle.ok) return '';
    return JWT.exec(await bundle.text())?.[0] || '';
  }

  let missedAt = 0;

  function get() {
    // The bundle is ~3 MB, so a miss waits out RETRY_MS instead of refetching per request.
    if (!pending && Date.now() - missedAt >= RETRY_MS) {
      pending = load().catch(() => '');
      pending.then((token) => {
        if (token) return;
        missedAt = Date.now();
        pending = null;
      });
    }
    return pending || Promise.resolve('');
  }

  function reset() {
    pending = null;
  }

  return { get, reset };
}
