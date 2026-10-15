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

import { base64url, encodeJsonSegment, encoder } from "./crypto.js";
import { HttpError, json, nowSeconds } from "./http.js";

export const APPLE_DEVELOPER_TOKEN_SECONDS = 60 * 60;

const APPLE_ID_PATTERN = /^[A-Z0-9]{10}$/;

function unavailable() {
  return new HttpError(503, "apple_music_unavailable", "Apple Music is unavailable");
}

async function importPrivateKey(pem) {
  const match = pem.replace(/\\n/g, "\n").trim().match(
    /^-----BEGIN PRIVATE KEY-----\s+([A-Za-z0-9+/=\s]+)\s+-----END PRIVATE KEY-----$/,
  );
  if (!match) throw unavailable();
  const bytes = Uint8Array.from(atob(match[1].replace(/\s/g, "")), (char) => char.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", bytes, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

export async function appleDeveloperToken(env) {
  const keyId = String(env.APPLE_MUSIC_KEY_ID || "").trim();
  const teamId = String(env.APPLE_MUSIC_TEAM_ID || "").trim();
  const pem = env.APPLE_MUSIC_PRIVATE_KEY;
  if (!APPLE_ID_PATTERN.test(keyId) || !APPLE_ID_PATTERN.test(teamId) || typeof pem !== "string" || !pem.trim()) {
    throw unavailable();
  }

  const now = nowSeconds();
  const expiresAt = now + APPLE_DEVELOPER_TOKEN_SECONDS;
  const header = encodeJsonSegment({ alg: "ES256", kid: keyId });
  const claims = encodeJsonSegment({ iss: teamId, iat: now, exp: expiresAt });
  const input = `${header}.${claims}`;
  let signature;
  try {
    const key = await importPrivateKey(pem);
    // Web Crypto returns the fixed-width r || s signature required by ES256.
    signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(input));
  } catch {
    console.error(JSON.stringify({ event: "apple_music_signing_failed" }));
    throw unavailable();
  }
  return json({ developer_token: `${input}.${base64url(new Uint8Array(signature))}`, expires_at: expiresAt });
}
