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

// Reads YouTube's "Made with AI" disclosure. Only the WEB watch response carries it;
// YouTube Music's `next` has neither the badge nor the description section.

const endpoint = 'https://www.youtube.com/youtubei/v1/next?prettyPrint=false';
const clientVersion = '2.20261013.00.00';
const requestTimeoutMs = 8000;

function primaryBadges(data) {
  const contents = data?.contents?.twoColumnWatchNextResults?.results?.results?.contents;
  if (!Array.isArray(contents)) return [];
  return contents.flatMap((item) => item?.videoPrimaryInfoRenderer?.badges || [])
    .map((badge) => badge?.metadataBadgeRenderer)
    .filter(Boolean);
}

function disclosureSections(data) {
  const sections = [];
  for (const panel of data?.engagementPanels || []) {
    const items = panel?.engagementPanelSectionListRenderer?.content
      ?.structuredDescriptionContentRenderer?.items;
    for (const item of Array.isArray(items) ? items : []) {
      if (item?.howThisWasMadeSectionViewModel) sections.push(item.howThisWasMadeSectionViewModel);
    }
  }
  return sections;
}

// "How this was made" also covers camera provenance, so the section alone is not enough.
export function parseAiLabel(data) {
  if (primaryBadges(data).some((badge) => badge.label === 'AI' ||
      /made with AI/i.test(badge.accessibilityData?.label || ''))) return true;
  return disclosureSections(data).some((section) =>
    /made with AI/i.test(section.bodyHeader?.content || '') ||
    /altered or (fully generated|synthetic)/i.test(section.bodyText?.content || ''));
}

// Throws on network failure so callers never store a guess as a "no".
export async function loadAiLabel(payload = {}) {
  const videoId = String(payload.videoId || '').trim();
  if (!videoId) throw new Error('A video id is required.');
  let timer;
  const expired = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error('YouTube AI label request timed out.')), requestTimeoutMs);
  });
  try {
    const response = await Promise.race([
      fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // hl stays English so the label text matches.
        body: JSON.stringify({
          context: { client: { clientName: 'WEB', clientVersion, hl: 'en', gl: 'US' } },
          videoId
        })
      }),
      expired
    ]);
    if (!response.ok) throw new Error(`YouTube AI label request failed (${response.status})`);
    return { videoId, ai: parseAiLabel(await response.json()) };
  } finally {
    clearTimeout(timer);
  }
}
