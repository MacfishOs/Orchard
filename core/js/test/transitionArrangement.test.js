/* Copyright (C) 2026 SFG545. Licensed under the Orchard-Only License (OOL-1.0), see LICENSE-OOL. */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { finalizeTrackAnalysis } from '../shared/trackAnalysis.js';
import { planPairTransition } from '../src/audio/crossfade/pairTransitionPlanner.js';
import { TECHNIQUE, createArrangement } from '../src/audio/crossfade/transitionArrangement.js';

const fixtures = JSON.parse(
  readFileSync(new URL('./fixtures/transitionChoreography.json', import.meta.url), 'utf8')
);

function planFor(name) {
  const fixture = fixtures[name];
  const outgoing = finalizeTrackAnalysis(fixture.outgoing);
  const incoming = finalizeTrackAnalysis(fixture.incoming);
  return planPairTransition({
    analysis: outgoing,
    nextAnalysis: incoming,
    duration: outgoing.duration,
    nextDuration: incoming.duration
  });
}

test('arrangements reject unknown techniques and normalize fade spans', () => {
  assert.throws(() => createArrangement({ technique: 'surprise_drop' }), /Unknown transition technique/);
  const arrangement = createArrangement({
    technique: TECHNIQUE.BRIDGE, outgoingFade: [-1, 0.6], incomingFade: [0.2, 3]
  });
  assert.deepEqual(arrangement.outgoingFade, [0, 0.6]);
  assert.deepEqual(arrangement.incomingFade, [0.2, 1]);
  // A span too short to fade over is a full-length fade, never a click.
  assert.deepEqual(createArrangement({ technique: TECHNIQUE.BLEND, outgoingFade: [0.5, 0.505] }).outgoingFade, [0, 1]);
});

test('a refused pair carries the boundary arrangement', () => {
  const plan = planFor('blinding_lights_to_dont_start_now');
  assert.notEqual(plan.renderMode, 'native');
  assert.equal(plan.arrangement.technique, TECHNIQUE.BOUNDARY);
  assert.equal(plan.durationSeconds, 0);
});

test('a safe instrumental blend hands the bass over once, inside the overlap', () => {
  const plan = planFor('safe_instrumental_blend');
  assert.equal(plan.renderMode, 'native');
  assert.ok(plan.durationSeconds >= 3 && plan.durationSeconds <= 16);
  assert.equal(plan.arrangement.technique, plan.strategy === 'bass_swap' ? TECHNIQUE.BASS_SWAP : TECHNIQUE.BLEND);
  assert.equal(plan.arrangement.bassSwapFraction, plan.bassSwapFraction);
  assert.ok(plan.bassSwapFraction >= 0.375 && plan.bassSwapFraction <= 0.75);
  assert.deepEqual(plan.arrangement.outgoingFade, [0, 1]);
  assert.deepEqual(plan.arrangement.incomingFade, [0, 1]);
});

test('a sustained vocal collision never earns a full beatmatched mix', () => {
  assert.notEqual(planFor('sustained_vocal_collision').transitionClass, 'full_beatmatched');
});

test('weak evidence keeps a boundary arrangement exactly when nothing is rendered', () => {
  const plan = planFor('weak_evidence_pair');
  assert.equal(plan.arrangement.technique === TECHNIQUE.BOUNDARY, plan.renderMode !== 'native');
});
