/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

// This module is deliberately an adapter. PairTransitionPlanner owns every
// musical choice; this file only exposes its exact native-render fields in the
// shape the existing preparation/playback path understands.
import { normalizeTrackAnalysis } from '../../../shared/trackAnalysis.js';
import { planPairTransition } from './pairTransitionPlanner.js';
export { alignTempoOctave } from './pairTempoHarmony.js';

const SLICE_PADDING_SECONDS = 1.5;
const HANDOFF_FRACTION = 0.5;
const BED_POSITION = 0.5;

function finite(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function canonicalAnalysis(value = {}, duration = 0) {
  if (
    value?.timing &&
    value?.audibleRange &&
    Array.isArray(value?.frames) &&
    Array.isArray(value?.boundaries)
  ) return value;
  return normalizeTrackAnalysis({
    ...value,
    duration: Math.max(finite(value.duration), finite(duration))
  });
}

function sliceFor(start, end, duration) {
  const sliceStart = Math.max(0, start - SLICE_PADDING_SECONDS);
  const sliceEnd = Math.min(duration || Infinity, end + SLICE_PADDING_SECONDS);
  return {
    start: sliceStart,
    end: sliceEnd,
    anchor: start - sliceStart
  };
}

function refusal(pairPlan) {
  return {
    ok: false,
    reason: pairPlan.fallbackReason || pairPlan.transitionClass,
    explain: pairPlan.explain ?? null,
    fallback: pairPlan.fallback,
    pairPlan
  };
}

export function planWsolaTransition({
  analysis = {},
  nextAnalysis = {},
  duration = 0,
  nextDuration = 0,
  tempoRamp = false,
  outgoingWindowStart = null,
  incomingWindowEnd = null
} = {}) {
  const pairPlan = planPairTransition({
    analysis, nextAnalysis, duration, nextDuration, tempoRamp, outgoingWindowStart, incomingWindowEnd
  });
  if (pairPlan.renderMode !== 'native') return refusal(pairPlan);

  const outgoing = canonicalAnalysis(analysis, duration);
  const incoming = canonicalAnalysis(nextAnalysis, nextDuration);
  const outgoingLength = Math.max(finite(duration), finite(outgoing.duration));
  const incomingLength = Math.max(finite(nextDuration), finite(incoming.duration));
  const outgoingGrid = {
    bpm: finite(outgoing.timing?.bpm),
    beats: [...(outgoing.timing?.beats || [])],
    downbeats: [...(outgoing.timing?.downbeats || [])]
  };
  const incomingGrid = {
    bpm: finite(incoming.timing?.bpm),
    beats: [...(incoming.timing?.beats || [])],
    downbeats: [...(incoming.timing?.downbeats || [])]
  };
  const selectedSources = pairPlan.diagnostics?.selected?.sources || [];
  const selectedGates = pairPlan.diagnostics?.selected?.gates || [];

  return {
    ok: true,
    pairPlan,
    fallback: pairPlan.fallback,
    outgoingGrid,
    incomingGrid,
    tier: pairPlan.transitionClass === 'beatless_bridge' ? 'bridge' : 'beatmatched',
    beatConfidence: Math.min(
      finite(outgoing.timing?.beatConfidence),
      finite(incoming.timing?.beatConfidence)
    ),
    mixOutType: selectedSources[0] || '',
    vocalClash: selectedGates.includes('vocal-collision'),
    transitionStart: pairPlan.outgoing.start,
    transitionEnd: pairPlan.outgoing.end,
    overlapSeconds: pairPlan.durationSeconds,
    beats: pairPlan.beats,
    fadeBeats: pairPlan.beats,
    handoffFraction: HANDOFF_FRACTION,
    bedPosition: BED_POSITION,
    bassSwapFraction: pairPlan.bassSwapFraction ?? null,
    outgoingLoop: pairPlan.outgoingLoop ?? null,
    filterSweep: pairPlan.rendering.filters ? 1 : 0,
    outgoingBpm: outgoingGrid.bpm,
    incomingBpm: incomingGrid.bpm,
    targetBpm: pairPlan.targetBpm,
    outgoingTempoRatio: pairPlan.outgoing.tempoRatio,
    incomingTempoRatio: pairPlan.incoming.tempoRatio,
    ...(pairPlan.tempoRamp ? { tempoRamp: true } : {}),
    stretchRatio: pairPlan.outgoing.tempoRatio,
    incomingCueTime: pairPlan.incoming.start,
    incomingDropTime: pairPlan.incoming.handoff,
    incomingResumeTime: pairPlan.incoming.resume,
    strategy: pairPlan.strategy,
    technique: pairPlan.technique,
    arrangement: pairPlan.arrangement,
    outgoingSlice: sliceFor(
      pairPlan.outgoing.start,
      pairPlan.outgoing.end,
      outgoingLength
    ),
    incomingSlice: sliceFor(
      pairPlan.incoming.start,
      pairPlan.incoming.resume,
      incomingLength
    )
  };
}
