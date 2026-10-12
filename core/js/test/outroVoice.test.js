import test from 'node:test';
import assert from 'node:assert/strict';

import { normalizeTrackAnalysis } from '../shared/trackAnalysis.js';
import { singsOut } from '../src/audio/crossfade/transitionFlow.js';

// 60 s song: voice share and bass level from functions of time, sampled every 0.25 s.
function song({ voice, bass }) {
  const times = Array.from({ length: 240 }, (_, index) => index * 0.25);
  return normalizeTrackAnalysis({
    duration: 60,
    contentEndTime: 60,
    bpm: 120,
    beats: Array.from({ length: 120 }, (_, index) => index * 0.5),
    vocalCurve: { start: 0, step: 0.25, values: times.map(voice) },
    bassCurve: { start: 0, step: 0.25, values: times.map(bass) }
  });
}

const winding = (time) => (time < 54 ? 1 : 0.02);

test('adlibs over a winding-down outro sing the song out', () => {
  assert.equal(singsOut(song({ voice: () => 0.9, bass: winding }), 48), true);
});

test('a pause before the end lets the line finish', () => {
  const voice = (time) => (time > 52 && time < 55 ? 0 : 0.9);
  assert.equal(singsOut(song({ voice, bass: winding }), 48), false);
});

test('a song that stops at full tilt keeps its last line', () => {
  assert.equal(singsOut(song({ voice: () => 0.9, bass: () => 1 }), 48), false);
  assert.equal(singsOut(song({ voice: () => 0.9, bass: winding }), 58), false);
});
