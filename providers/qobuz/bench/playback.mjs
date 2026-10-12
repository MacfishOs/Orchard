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
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { setTimeout } from 'node:timers/promises';
import { audioSegment, initSegment, response } from '../test/fixtures/cmaf.js';

const source = process.argv[2] ? pathToFileURL(resolve(process.argv[2]) + '/') : new URL('../src/', import.meta.url);
const { createQobuzPlayback } = await import(new URL('playback.js', source));
const { decryptQobuzAudioSegment, parseQobuzInitSegment } = await import(new URL('cmaf.js', source));
const runs = 7, segmentBytes = 128 * 1024, rangeBytes = 512 * 1024, latencyMs = 40;
const init = initSegment(Array(64).fill(segmentBytes));
const headerBytes = parseQobuzInitSegment(init).flacHeader.length;
const audioBytes = new Uint8Array(segmentBytes).fill(123);
const raw = audioSegment([{ data: audioBytes }]);

function median(values) {
  return values.sort((a, b) => a - b)[Math.floor(values.length / 2)];
}

async function rangeBenchmark(label, start) {
  const times = [];
  let peak = 0, requests = 0;
  for (let run = 0; run < runs; run++) {
    let active = 0;
    const playback = createQobuzPlayback({
      client: { streamingInfo: async () => ({ url_template: 'https://test/$SEGMENT$' }) },
      randomUuid: () => 'bench',
      fetchImpl: async (url) => {
        if (url.endsWith('/0')) return response(init);
        requests++;
        peak = Math.max(peak, ++active);
        await setTimeout(latencyMs);
        active--;
        return response(raw);
      }
    });
    await playback.resolveStream({ qobuzTrackId: 1 }, 'lossless');
    const started = performance.now();
    const result = await playback.readRange('bench', { start, end: start + rangeBytes - 1 });
    times.push(performance.now() - started);
    assert.equal(result.bytes.length, rangeBytes);
    const audioStart = Math.max(0, headerBytes - start);
    assert.ok(result.bytes.subarray(audioStart).every((byte) => byte === 123));
  }
  console.log(`${label}: median ${median(times).toFixed(1)} ms; peak downloads ${peak}; requests/run ${requests / runs}`);
}

console.log(`Synthetic CMAF ranges: ${runs} runs, ${latencyMs} ms/fetch, 128 KiB/segment, 512 KiB/read`);
await rangeBenchmark('Startup', 0);
await rangeBenchmark('Seek', headerBytes + 10 * segmentBytes + 1024);

async function firstAudioBenchmark() {
  const times = [], metadataTimes = [];
  for (let run = 0; run < runs; run++) {
    const playback = createQobuzPlayback({
      client: { streamingInfo: async () => ({ url_template: 'https://test/$SEGMENT$' }) },
      randomUuid: () => 'bench',
      fetchImpl: async (url) => {
        if (url.endsWith('/0')) return response(init);
        await setTimeout(url.endsWith('/1') ? 40 : 200);
        return response(raw);
      }
    });
    await playback.resolveStream({ qobuzTrackId: 1 }, 'lossless');
    const read = (range) => playback.readChunk ? playback.readChunk('bench', range) : playback.readRange('bench', range);
    const started = performance.now();
    const metadata = await read({ start: 0, end: rangeBytes - 1 });
    metadataTimes.push(performance.now() - started);
    const audio = metadata.end >= headerBytes ? metadata : await read({ start: metadata.end + 1, end: rangeBytes - 1 });
    times.push(performance.now() - started);
    assert.ok(audio.bytes.length > 0);
  }
  console.log(`First audio (later segments take 200 ms): median ${median(times).toFixed(1)} ms; metadata ${median(metadataTimes).toFixed(1)} ms`);
}
await firstAudioBenchmark();

const framed = audioSegment(Array.from({ length: 128 }, () => ({ data: new Uint8Array(8192).fill(123) })));
const times = [];
for (let run = 0; run <= runs; run++) {
  const started = performance.now();
  for (let iteration = 0; iteration < 200; iteration++) {
    const result = decryptQobuzAudioSegment(framed, null, {});
    assert.equal(result.length, 1024 * 1024);
    assert.equal(result[0], 123);
  }
  if (run) times.push(performance.now() - started);
}
console.log(`Clear frame assembly: median ${median(times).toFixed(1)} ms for 200 x 1 MiB segments`);
