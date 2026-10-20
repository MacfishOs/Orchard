/* Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
import { hashSecret } from './crypto.js';
import { HttpError, json, nowSeconds, requireSession } from './http.js';

export async function translationContext(request, env) {
  const claims = await requireSession(request, env);
  // Cloudflare sets this header at ingress.
  const ip = request.headers.get('cf-connecting-ip');
  if (!ip) throw new HttpError(403, 'missing_client_ip', 'Translation requires a Cloudflare connection');
  const ipHash = await hashSecret(`${env.SIGNING_KEY}\u001ftranslation-ip\u001f${ip}`);
  return { accountId: claims.sub, ipHash };
}

export async function readTranslationQuota(env, { accountId, ipHash }) {
  const day = Math.floor(nowSeconds() / 86400);
  const row = await env.DB.prepare(`SELECT translation_daily_limit AS daily_limit,
    COALESCE((SELECT used FROM translation_daily_usage WHERE scope = 'account' AND subject = users.id AND day = ?), 0) AS account_used,
    COALESCE((SELECT used FROM translation_daily_usage WHERE scope = 'ip' AND subject = ? AND day = ?), 0) AS ip_used
    FROM users WHERE id = ?`).bind(day, ipHash, day, accountId).first();
  if (!row) throw new HttpError(401, 'invalid_token', 'Account no longer exists');
  const accountRemaining = Math.max(0, row.daily_limit - row.account_used);
  const ipRemaining = row.daily_limit <= 10 ? Math.max(0, 10 - row.ip_used) : null;
  return {
    daily_limit: row.daily_limit,
    account_remaining: accountRemaining,
    ip_remaining: ipRemaining,
    remaining: ipRemaining === null ? accountRemaining : Math.min(accountRemaining, ipRemaining),
    resets_at: (day + 1) * 86400,
  };
}

export async function translationQuota(request, env) {
  const context = await translationContext(request, env);
  return json({ quota: await readTranslationQuota(env, context) });
}
