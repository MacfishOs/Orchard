import test from 'node:test';
import assert from 'node:assert/strict';

import { cueTempoFit, holdsTempo, sectionBpm } from '../src/audio/crossfade/sectionTempo.js';

// Beat times from consecutive [count, interval] runs.
function beats(...runs) {
  const times = [0];
  for (const [count, interval] of runs) {
    for (let index = 0; index < count; index += 1) times.push(times.at(-1) + interval);
  }
  return times;
}

const song = (bpm, times) => ({ timing: { bpm, beats: times } });

test('steady sections read the song tempo, swing included', () => {
  const swung = beats(...Array.from({ length: 40 }, (_, index) => [1, index % 2 ? 0.55 : 0.45]));
  assert.equal(sectionBpm(song(120, swung), 10, 12), 120);
  assert.equal(sectionBpm(song(120, beats([100, 0.5])), 40, 48), 120);
});

test('a steady section at another tempo reads its own tempo', () => {
  // 130 BPM song whose outro settles at 120.
  const analysis = song(130, beats([200, 60 / 130], [40, 0.5]));
  const outro = analysis.timing.beats.at(-1);
  assert.ok(Math.abs(sectionBpm(analysis, outro - 8, outro) - 120) < 0.01);
});

test('a slowing section cannot be beatmatched', () => {
  const ritardando = Array.from({ length: 16 }, (_, index) => [1, 0.86 + index * 0.02]);
  const analysis = song(70, beats([150, 0.857], ...ritardando));
  const end = analysis.timing.beats.at(-1);
  assert.equal(sectionBpm(analysis, end - 8, end), null);
  assert.equal(holdsTempo(analysis, end - 8, end, 70), false);
  const fit = cueTempoFit(analysis, song(70, beats([100, 0.857])), end, 20, { tempoRamp: true });
  assert.equal(fit.beatmatched, false);
  assert.equal(fit.movingTempo, true);
});

test('cue fits compare native section tempos across octaves', () => {
  const fast = song(140, beats([300, 60 / 140]));
  const slow = song(69, beats([150, 60 / 69]));
  const fit = cueTempoFit(fast, slow, 100, 20, { tempoRamp: true });
  assert.equal(fit.beatmatched, true);
  assert.deepEqual(fit.sections, [140, 69]);
  assert.equal(holdsTempo(slow, 10, 20, fit.sections[1]), true);
});
