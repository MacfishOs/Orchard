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

import assert from 'node:assert/strict';
import { createCipheriv, createDecipheriv } from 'node:crypto';
import test from 'node:test';
import { concatBytes } from '../src/bytes.js';
import { decryptQobuzAudioSegment, parseQobuzInitSegment } from '../src/cmaf.js';
import { createQobuzPlayback } from '../src/playback.js';
import { audioSegment, deferred, initSegment, response } from './fixtures/cmaf.js';

async function fixture({ lengths = [8, 8, 8, 8, 8, 8], fetchAudio, streamingInfo } = {}) {
  const init = initSegment(lengths);
  const parsed = parseQobuzInitSegment(init);
  const audio = lengths.map((length, index) => new Uint8Array(length).fill(index + 1));
  const raw = audio.map((data) => audioSegment([{ data }]));
  const requests = [];
  const playback = createQobuzPlayback({
    client: { streamingInfo: streamingInfo || (async () => ({ url_template: 'https://test/$SEGMENT$' })) },
    randomUuid: () => 'playback',
    fetchImpl: async (url) => {
      const number = Number(url.split('/').at(-1));
      if (!number) return response(init);
      requests.push(number);
      return fetchAudio ? fetchAudio(number, raw[number - 1], url) : response(raw[number - 1]);
    }
  });
  const source = await playback.resolveStream({ qobuzTrackId: 1 }, 'lossless');
  return { playback, source, requests, header: parsed.flacHeader, audio, bytes: concatBytes([parsed.flacHeader, ...audio]) };
}

test('startup downloads overlap and assemble bytes in order with a four-segment limit', async () => {
  const gates = Array.from({ length: 6 }, deferred);
  const f = await fixture({ fetchAudio: async (number, raw) => {
    await gates[number - 1].promise;
    return response(raw);
  } });
  const read = f.playback.readRange(f.source.playbackId);
  assert.deepEqual(f.requests, [1, 2, 3, 4]);
  // Complete the first batch out of order; the next batch must wait.
  gates[3].resolve(); gates[1].resolve(); gates[2].resolve();
  await new Promise(setImmediate);
  assert.deepEqual(f.requests, [1, 2, 3, 4]);
  gates[0].resolve();
  await new Promise(setImmediate);
  assert.deepEqual(f.requests, [1, 2, 3, 4, 5, 6]);
  gates[5].resolve(); gates[4].resolve();
  assert.deepEqual((await read).bytes, f.bytes);
});

test('seeks fetch only intersecting segments and preserve partial edges', async () => {
  const f = await fixture({ lengths: [3, 7, 2, 9, 4, 8] });
  const start = f.header.length + 10;
  const end = start + 2 + 9 + 1;
  const result = await f.playback.readRange(f.source.playbackId, { start, end });
  assert.deepEqual(result.bytes, f.bytes.slice(start, end + 1));
  assert.deepEqual(f.requests, [3, 4, 5]);
  assert.equal(result.start, start);
  assert.equal(result.end, end);
  assert.equal(result.totalLength, f.bytes.length);
  assert.deepEqual((await f.playback.readRange(f.source.playbackId, { start: start + 1, end })).bytes,
    f.bytes.slice(start + 1, end + 1));
  assert.deepEqual(f.requests, [3, 4, 5]);
});

test('metadata reads need no audio download, and EOF reads clamp correctly', async () => {
  const f = await fixture();
  assert.deepEqual((await f.playback.readRange(f.source.playbackId, { end: f.header.length - 1 })).bytes, f.header);
  assert.deepEqual(f.requests, []);
  assert.deepEqual((await f.playback.readRange(f.source.playbackId, {
    start: f.bytes.length - 1, end: f.bytes.length + 100
  })).bytes, f.bytes.slice(-1));
  assert.deepEqual(f.requests, [6]);
  await assert.rejects(f.playback.readRange(f.source.playbackId, { start: f.bytes.length }), RangeError);
});

test('overlapping seek reads share downloads still in flight', async () => {
  const gate = deferred();
  const f = await fixture({ fetchAudio: async (_number, raw) => { await gate.promise; return response(raw); } });
  const first = f.playback.readRange(f.source.playbackId, { start: f.header.length + 1, end: f.header.length + 14 });
  const second = f.playback.readRange(f.source.playbackId, { start: f.header.length + 8, end: f.header.length + 15 });
  assert.deepEqual(f.requests, [1, 2]);
  gate.resolve();
  assert.deepEqual((await first).bytes, f.bytes.slice(f.header.length + 1, f.header.length + 15));
  assert.deepEqual((await second).bytes, f.audio[1]);
});

test('parallel expired segments share renewal and keep retry downloads deduplicated', async () => {
  const renewal = deferred(), retry = deferred();
  let renewals = 0;
  const f = await fixture({
    streamingInfo: async () => {
      if (renewals++) await renewal.promise;
      return { url_template: `https://test/${renewals === 1 ? 'expired' : 'fresh'}/$SEGMENT$` };
    },
    fetchAudio: async (_number, raw, url) => {
      if (url.includes('/expired/')) return response(raw, 403);
      await retry.promise;
      return response(raw);
    }
  });
  const range = { start: f.header.length, end: f.header.length + 15 };
  const first = f.playback.readRange(f.source.playbackId, range);
  await new Promise(setImmediate);
  assert.equal(renewals, 2);
  const second = f.playback.readRange(f.source.playbackId, range);
  renewal.resolve();
  await new Promise(setImmediate);
  assert.deepEqual(f.requests, [1, 2, 1, 2]);
  retry.resolve();
  const results = await Promise.all([first, second]);
  for (const result of results) assert.deepEqual(result.bytes, f.bytes.slice(range.start, range.end + 1));
});

test('an expired retry fails once, and failed segments can be requested again', async () => {
  let failing = true;
  const f = await fixture({ fetchAudio: async (_number, raw) => response(raw, failing ? 403 : 200) });
  const range = { start: f.header.length, end: f.header.length + 7 };
  await assert.rejects(f.playback.readRange(f.source.playbackId, range), /failed \(403\)/);
  assert.deepEqual(f.requests, [1, 1]);
  failing = false;
  assert.deepEqual((await f.playback.readRange(f.source.playbackId, range)).bytes, f.audio[0]);
  assert.deepEqual(f.requests, [1, 1, 1]);
});

test('CMAF frame views decrypt exactly and do not modify the fetched segment', () => {
  const key = new Uint8Array(16).fill(42), iv = new Uint8Array(16).fill(7);
  const clear = Uint8Array.of(0, 1, 2, 255), plaintext = new Uint8Array(81).fill(123);
  const cipher = createCipheriv('aes-128-ctr', key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tail = Uint8Array.of(99, 100);
  const raw = audioSegment([{ data: clear }, { data: encrypted, flags: 1, iv }], tail);
  const original = raw.slice();
  const result = decryptQobuzAudioSegment(raw, key, {
    decryptAes128Ctr: ({ key, iv, data }) => {
      assert.equal(data.buffer, raw.buffer);
      const cipher = createDecipheriv('aes-128-ctr', key, iv);
      return Buffer.concat([cipher.update(data), cipher.final()]);
    }
  });
  assert.deepEqual(result, concatBytes([clear, plaintext, tail]));
  assert.deepEqual(raw, original);
  result.fill(0);
  assert.deepEqual(raw, original);
});

test('streaming yields metadata and first audio while later downloads are pending', async () => {
  const gates = Array.from({ length: 6 }, deferred);
  const f = await fixture({ fetchAudio: async (number, raw) => {
    await gates[number - 1].promise;
    return response(raw);
  } });
  assert.deepEqual((await f.playback.readChunk(f.source.playbackId, { end: f.header.length - 1 })).bytes, f.header);
  assert.deepEqual(f.requests, []);
  const metadata = await f.playback.readChunk(f.source.playbackId);
  assert.deepEqual(metadata.bytes, f.header);
  assert.equal(metadata.end, f.header.length - 1);
  assert.deepEqual(f.requests, [1, 2, 3, 4]);
  const read = f.playback.readChunk(f.source.playbackId, { start: metadata.end + 1 });
  gates[0].resolve();
  const audio = await read;
  assert.deepEqual(audio.bytes, f.audio[0]);
  assert.equal(audio.end, f.header.length + 7);
  assert.deepEqual(f.requests, [1, 2, 3, 4]);
  for (const gate of gates) gate.resolve();
});

test('streaming seek reads preserve exact ranges, including mid-segment and EOF edges', async () => {
  const f = await fixture({ lengths: [3, 7, 2, 9, 4, 8] });
  const start = f.header.length + 12, end = f.bytes.length + 10;
  const chunks = [];
  let offset = start;
  while (offset < f.bytes.length) {
    const result = await f.playback.readChunk(f.source.playbackId, { start: offset, end });
    assert.equal(result.start, offset);
    assert.equal(result.end, offset + result.bytes.length - 1);
    chunks.push(result.bytes);
    offset = result.end + 1;
  }
  assert.deepEqual(concatBytes(chunks), f.bytes.slice(start));
  assert.deepEqual(f.requests, [4, 5, 6]);
  await assert.rejects(f.playback.readChunk(f.source.playbackId, { start: f.bytes.length }), RangeError);
});
