/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

import assert from 'node:assert/strict';
import test from 'node:test';

import { normalizeTrackAnalysis } from '../shared/trackAnalysis.js';
import {
  buildCandidatePairs,
  generateTransitionCandidates,
  tempoFit
} from '../src/audio/crossfade/pairTransitionEvidence.js';
import { planPairTransition } from '../src/audio/crossfade/pairTransitionPlanner.js';
import { TECHNIQUE, fadeSpansFor } from '../src/audio/crossfade/transitionArrangement.js';
import { bassSwapFraction, incomingVoiceRisk, outgoingExit } from '../src/audio/crossfade/transitionFlow.js';
import { raw } from './fixtures/workerAnalysis.js';

const plan = (analysis, nextAnalysis, extra = {}) => planPairTransition({
  analysis, nextAnalysis, duration: analysis.duration, nextDuration: nextAnalysis.duration, tempoRamp: true, ...extra
});

test('beatless edges bridge two tempos no glide can match', () => {
  const result = plan(
    raw({ bpm: 90, beatUntil: 110, boundaries: [100] }),
    raw({ bpm: 128, beatFrom: 10, boundaries: [10, 20] })
  );
  assert.equal(result.renderMode, 'native');
  assert.equal(result.technique, TECHNIQUE.BRIDGE);
  assert.equal(result.outgoing.tempoRatio, 1);
  assert.equal(result.incoming.tempoRatio, 1);
  // The old song plays to its end; the new beat lands as the bridge finishes.
  assert.equal(result.outgoing.end, 120);
  assert.ok(result.durationSeconds >= 4 && result.durationSeconds <= 12);
  assert.ok(result.incoming.handoff <= 10 + 1e-6);
  // Why no beatmatch was possible still reaches the diagnostics.
  assert.equal(result.diagnostics.beatmatch.code, 'tempo-distance');
});

test('no bridge when either song keeps its beat to the edge', () => {
  const result = plan(raw({ bpm: 90, boundaries: [100] }), raw({ bpm: 128, beatFrom: 10, boundaries: [10, 20] }));
  assert.equal(result.renderMode, 'boundary');
  assert.equal(result.fallbackReason, 'tempo-distance');
  assert.equal(result.explain.bridge.code, 'no-beatless-edge');
  assert.match(result.explain.detail, /90 vs 128 BPM/);
});

test('two voices over the bridge keep the songs apart', () => {
  const result = plan(
    raw({ bpm: 90, beatUntil: 110, vocal: () => 0.9, boundaries: [100] }),
    raw({ bpm: 128, beatFrom: 10, vocal: () => 0.9, boundaries: [10, 20] })
  );
  assert.equal(result.renderMode, 'boundary');
  assert.equal(result.explain.bridge.code, 'voice-over-voice');
});

test('an ordinary blend always wins over a drop-in when one exists', () => {
  const outgoing = raw({ boundaries: [104, 112] });
  const incoming = raw({ vocal: (time) => (time >= 0.5 ? 0.9 : 0.05), boundaries: [0.5] });
  const result = plan(outgoing, incoming, { incomingWindowEnd: 6 });
  assert.equal(result.renderMode, 'native');
  assert.notEqual(result.technique, TECHNIQUE.DROP_IN);
});

test('a drop-in lands at full level on the opening beat and leaves within half the overlap', () => {
  const outgoing = normalizeTrackAnalysis(raw({ boundaries: [104, 112] }));
  const incoming = normalizeTrackAnalysis(raw({ vocal: (time) => (time >= 0.5 ? 0.9 : 0.05), boundaries: [] }));
  const fit = tempoFit(120, 120, { tempoRamp: true });
  const [pair] = buildCandidatePairs(
    generateTransitionCandidates(outgoing, 'outgoing'),
    generateTransitionCandidates(incoming, 'incoming').filter((candidate) => candidate.anchorTime < 1),
    fit, { outgoingAnalysis: outgoing, incomingAnalysis: incoming, dropIn: true }
  ).finalists;
  assert.equal(pair.alignment, 'start');
  assert.equal(pair.beats, 8);
  assert.equal(pair.incomingStart, pair.incomingAnchor);
  // Nothing sings before the song starts, so the entry carries no line in progress.
  assert.equal(incomingVoiceRisk(pair, incoming), 0);
  assert.deepEqual(fadeSpansFor(pair), { outgoing: [0, 0.5], incoming: [0, 0.125] });
  assert.equal(bassSwapFraction(pair, incoming), 0.05);
  // The outgoing voice is judged where its fader closes, half way through.
  assert.ok(Math.abs(outgoingExit(pair) - (pair.outgoingStart + pair.outgoingEnd) / 2) < 1e-9);
});

test('a drop-in never pulls a singer out mid-line', () => {
  const singing = raw({ vocal: () => 0.9, boundaries: [104, 112] });
  const incoming = raw({ vocal: (time) => (time >= 0.5 ? 0.9 : 0.05), boundaries: [0.5] });
  const result = plan(singing, incoming, { incomingWindowEnd: 6 });
  assert.equal(result.renderMode, 'boundary');
});

test('a refusal explains the closest beatmatched candidate', () => {
  const result = plan(
    raw({ vocal: () => 0.9, boundaries: [104, 112] }),
    raw({ vocal: () => 0.1, boundaries: [16, 32] })
  );
  assert.equal(result.renderMode, 'boundary');
  assert.equal(result.fallbackReason, 'voice-cut');
  assert.equal(result.explain.category, 'vocals');
  assert.match(result.explain.detail, /mid-line/);
  // A refusal plays nothing, so it reports no overlap.
  assert.equal(result.durationSeconds, 0);
});
