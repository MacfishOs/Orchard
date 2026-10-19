import assert from 'node:assert/strict';
import { beforeEach, afterEach, it, mock } from 'node:test';
import worker from '../src/index.js';
import { signJwt } from '../src/jwt.js';
import { TRANSLATION_MODEL, purgeTranslations } from '../src/translation.js';
import { createD1 } from './d1.js';

let env, token, calls;
const now = () => Math.floor(Date.now() / 1000);
async function session(user = 'user-1', device = 'device-1') {
  env.DB.raw.prepare('INSERT OR IGNORE INTO users (id, created_at, updated_at) VALUES (?, 0, 0)').run(user);
  env.DB.raw.prepare(`INSERT OR IGNORE INTO devices
    (id, user_id, name, platform, refresh_hash, rotated_at, created_at, last_seen_at)
    VALUES (?, ?, 'Desk', 'linux', ?, 0, 0, ?)`).run(device, user, `hash-${device}`, now());
  return signJwt({ iss: env.PUBLIC_URL, aud: 'orchard', sub: user, did: device, iat: now(), exp: now() + 900 }, env.SIGNING_KEY);
}
function translate(song = 'song-1', { auth = token, ip = '203.0.113.7', lines = ['Hola'], extra = {} } = {}) {
  return worker.fetch(new Request('https://account.test/lyrics/translate', {
    method: 'POST', headers: { authorization: `Bearer ${auth}`, ...(ip ? { 'cf-connecting-ip': ip } : {}) },
    body: JSON.stringify({ song_id: song, lines, ...extra }),
  }), env);
}
function usage(scope = 'account', subject = 'user-1') {
  return env.DB.raw.prepare('SELECT used FROM translation_daily_usage WHERE scope = ? AND subject = ? AND day = ?')
    .get(scope, subject, Math.floor(now() / 86400))?.used ?? 0;
}
beforeEach(async () => {
  const { privateKey } = await crypto.subtle.generateKey({ name: 'Ed25519' }, true, ['sign', 'verify']);
  calls = 0;
  env = { DB: createD1(), PUBLIC_URL: 'https://account.test',
    SIGNING_KEY: JSON.stringify({ ...(await crypto.subtle.exportKey('jwk', privateKey)), kid: 'test' }),
    AI: { async run(model, payload) {
      calls++;
      assert.equal(model, TRANSLATION_MODEL);
      assert.equal(payload.stream, false);
      const input = JSON.parse(payload.messages[1].content);
      return { choices: [{ message: { content: JSON.stringify(input.map(line => `English: ${line}`)) } }] };
    } },
  };
  token = await session();
});
afterEach(() => mock.restoreAll());

it('requires a live session and a Cloudflare IP even for cache reads', async () => {
  assert.equal((await translate('one', { auth: '' })).status, 401);
  assert.equal((await translate('one', { ip: '' })).status, 403);
  assert.equal((await translate()).status, 200);
  env.DB.raw.prepare('DELETE FROM devices WHERE id = ?').run('device-1');
  assert.equal((await translate()).status, 401);
  assert.equal(calls, 1);
});
it('stores song IDs in D1 and shares cache across accounts without charging replays', async () => {
  const first = await (await translate()).json();
  assert.deepEqual(first.lines, ['English: Hola']);
  assert.equal(first.cached, false);
  assert.equal(env.DB.raw.prepare('SELECT song_id FROM lyric_translations').get().song_id, 'song-1');
  const other = await session('user-2', 'device-2');
  const replay = await (await translate('song-1', { auth: other })).json();
  assert.equal(replay.cached, true);
  assert.equal(calls, 1);
  assert.equal(usage(), 1);
  assert.equal(usage('account', 'user-2'), 0);
  assert.equal((await translate('song-2')).status, 200);
  assert.equal(calls, 2);
});
it('charges lyric changes under the same ID and ignores client quota/model fields', async () => {
  for (let i = 0; i < 10; i++) {
    assert.equal((await translate('same-id', { lines: [`Hola ${i}`],
      extra: { account_id: 'fake', ip: `fake-${i}`, day: i, cached: true, model: 'fake' } })).status, 200);
  }
  assert.equal((await translate('same-id', { lines: ['changed'] })).status, 429);
  assert.equal(calls, 10);
});
it('enforces an account limit across devices and IPs, while cached songs remain available', async () => {
  const secondDevice = await session('user-1', 'device-2');
  for (let i = 0; i < 10; i++) {
    assert.equal((await translate(`song-${i}`, { auth: i % 2 ? token : secondDevice, ip: `203.0.113.${i}` })).status, 200);
  }
  const rejected = await translate('eleventh', { ip: '203.0.113.99' });
  assert.equal(rejected.status, 429);
  assert.ok(Number(rejected.headers.get('retry-after')) > 0);
  assert.equal((await translate('song-0')).status, 200);
  assert.equal(calls, 10);
});
it('enforces the IP limit across accounts', async () => {
  for (let i = 0; i < 10; i++) {
    const auth = await session(`user-${i}`, `device-${i}`);
    assert.equal((await translate(`song-${i}`, { auth })).status, 200);
  }
  const other = await session('user-new', 'device-new');
  assert.equal((await translate('extra', { auth: other })).status, 429);
  assert.equal(usage('account', 'user-new'), 0);
});
it('admits at most ten simultaneous misses', async () => {
  const results = await Promise.all(Array.from({ length: 30 }, (_, i) => translate(`song-${i}`)));
  assert.equal(results.filter(response => response.status === 200).length, 10);
  assert.equal(results.filter(response => response.status === 429).length, 20);
  assert.equal(calls, 10);
});
it('coalesces simultaneous requests for a song', async () => {
  let finish;
  const blocked = new Promise(resolve => { finish = resolve; });
  const original = env.AI.run;
  env.AI.run = async (...args) => { await blocked; return original(...args); };
  const pending = translate();
  // Yield until the reservation has been written.
  while (!env.DB.raw.prepare('SELECT 1 FROM lyric_translations').get()) await new Promise(resolve => setImmediate(resolve));
  assert.equal((await translate()).status, 409);
  finish();
  assert.equal((await pending).status, 200);
  assert.equal(calls, 1);
  assert.equal(usage(), 1);
});
it('resets exactly at UTC midnight without relying on scheduled cleanup', async () => {
  const midnight = (Math.floor(Date.now() / 86400000) + 1) * 86400000;
  mock.method(Date, 'now', () => midnight - 1000);
  token = await session();
  for (let i = 0; i < 10; i++) assert.equal((await translate(`song-${i}`)).status, 200);
  assert.equal((await translate('extra')).status, 429);
  mock.method(Date, 'now', () => midnight);
  assert.equal((await translate('extra')).status, 200);
  assert.equal(usage(), 1);
});
it('validates bounded input before admission and does not cache malformed model output', async () => {
  for (const lines of [[], [''], [42], ['x'.repeat(1025)], Array(201).fill('Hola')]) {
    assert.equal((await translate('bad', { lines })).status, 400);
  }
  assert.equal((await translate('huge', { lines: ['x'.repeat(50000)] })).status, 413);
  assert.equal(usage(), 0);
  env.AI.run = async () => ({ choices: [{ message: { content: '[]' } }] });
  for (let i = 0; i < 10; i++) assert.equal((await translate()).status, 502);
  assert.equal((await translate()).status, 429);
  assert.equal(env.DB.raw.prepare('SELECT count(*) AS count FROM lyric_translations').get().count, 0);
});
it('translates a full song in bounded batches and cleans up expired cache/usage', async () => {
  const lines = Array.from({ length: 49 }, (_, i) => `Hola ${i}`);
  const result = await (await translate('long-song', { lines })).json();
  assert.deepEqual(result.lines, lines.map(line => `English: ${line}`));
  assert.equal(calls, 3);
  assert.equal(usage(), 1);
  await purgeTranslations(env, now() + 91 * 86400);
  assert.equal(env.DB.raw.prepare('SELECT count(*) AS count FROM lyric_translations').get().count, 0);
  assert.equal(env.DB.raw.prepare('SELECT count(*) AS count FROM translation_daily_usage').get().count, 0);
});

it('reports provider capacity and timeout errors separately without leaking upstream text', async () => {
  env.AI.run = async () => { throw new Error('3040: private upstream details'); };
  const busy = await translate('busy');
  assert.equal(busy.status, 503);
  assert.equal((await busy.json()).error, 'translation_busy');
  assert.equal(busy.headers.get('retry-after'), '5');
  env.AI.run = async () => { throw new Error('3007: private upstream details'); };
  const timedOut = await translate('timeout');
  assert.equal(timedOut.status, 504);
  assert.equal((await timedOut.json()).error, 'translation_timeout');
  assert.equal(usage(), 2);
  assert.equal(env.DB.raw.prepare('SELECT count(*) AS count FROM lyric_translations').get().count, 0);
});
