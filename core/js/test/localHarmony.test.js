/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

import assert from 'node:assert/strict';
import test from 'node:test';

import { normalizeTrackAnalysis } from '../shared/trackAnalysis.js';
import { overlapHarmony } from '../src/audio/crossfade/localHarmony.js';
import { planPairTransition } from '../src/audio/crossfade/pairTransitionPlanner.js';
import { raw } from './fixtures/workerAnalysis.js';

// A C major scale profile, rotated to other keys; flat for drum-only material.
const C_MAJOR = [0.2, 0.01, 0.12, 0.01, 0.15, 0.1, 0.01, 0.18, 0.01, 0.12, 0.01, 0.08];
const rotate = (profile, semitones) => profile.map((_, pitch) => profile[(pitch - semitones + 12) % 12]);
const FLAT = new Array(12).fill(1 / 12);

function chromaCurve(duration, profile) {
  const count = Math.floor(duration / 0.5);
  return { start: 0.25, step: 0.5, values: Array.from({ length: count }, () => profile), weights: new Array(count).fill(1) };
}

function track(options, profile) {
  return normalizeTrackAnalysis({ ...raw(options), chromaCurve: chromaCurve(options.duration ?? 120, profile) });
}

const span = { outgoingStart: 100, outgoingEnd: 108, incomingStart: 0, incomingEnd: 8 };

test('the same key and a fifth blend; a tritone between two tonal sides clashes', () => {
  const outgoing = track({}, C_MAJOR);
  const same = overlapHarmony(outgoing, track({}, C_MAJOR), span);
  const fifth = overlapHarmony(outgoing, track({}, rotate(C_MAJOR, 7)), span);
  const tritone = overlapHarmony(outgoing, track({}, rotate(C_MAJOR, 6)), span);
  assert.ok(same.score > 0.7 && !same.severeClash);
  assert.ok(fifth.score > 0.55 && !fifth.severeClash);
  assert.ok(tritone.correlation < -0.3 && tritone.severeClash);
});

test('drums over chords carry no harmonic opinion', () => {
  const harmony = overlapHarmony(track({}, C_MAJOR), track({}, FLAT), span);
  assert.equal(harmony.confidence, 0);
  assert.equal(harmony.score, 0.5);
  assert.equal(harmony.severeClash, false);
});

test('without measured chroma the whole-song key evidence stands in', () => {
  assert.equal(overlapHarmony(normalizeTrackAnalysis(raw()), normalizeTrackAnalysis(raw()), span), null);
});

test('measured chroma leaves beatmatched plans to whole-song keys', () => {
  // Listeners kept a blend whose overlap measured a clash (Come Thru -> Top Down).
  const options = { duration: 120, boundaries: [104, 8] };
  const request = (chroma) => ({
    analysis: { ...raw(options), ...(chroma ? { chromaCurve: chromaCurve(120, C_MAJOR) } : {}) },
    nextAnalysis: { ...raw(options), ...(chroma ? { chromaCurve: chromaCurve(120, rotate(C_MAJOR, 6)) } : {}) },
    duration: 120,
    nextDuration: 120,
    tempoRamp: true
  });
  const measured = planPairTransition(request(true));
  const plain = planPairTransition(request(false));
  assert.equal(measured.renderMode, 'native');
  assert.equal(measured.durationSeconds, plain.durationSeconds);
  assert.equal(measured.outgoing.start, plain.outgoing.start);
  assert.equal(measured.incoming.start, plain.incoming.start);
});

test('a bridge between clashing keys stays apart', () => {
  const bridge = (semitones) => planPairTransition({
    analysis: { ...raw({ bpm: 90, beatUntil: 110, boundaries: [100] }), chromaCurve: chromaCurve(120, C_MAJOR) },
    nextAnalysis: {
      ...raw({ bpm: 128, beatFrom: 10, boundaries: [10, 20] }),
      chromaCurve: chromaCurve(120, rotate(C_MAJOR, semitones))
    },
    duration: 120,
    nextDuration: 120,
    tempoRamp: true
  });
  const clash = bridge(6);
  assert.equal(clash.renderMode, 'boundary');
  assert.equal(clash.explain.bridge.code, 'harmonic-clash');
  assert.equal(bridge(7).technique, 'beatless_bridge');
});
