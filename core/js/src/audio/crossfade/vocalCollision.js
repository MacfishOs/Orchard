/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

// Two voices at once along a candidate's mapped timelines, stretch and glide included.
import { interpolateTrackFrame } from '../../../shared/trackAnalysis.js';
import { glideOffsets } from './pairTempoHarmony.js';

export const VOCAL_ACTIVE_THRESHOLD = 0.6;

function finite(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function rounded(value, places = 6) {
  const scale = 10 ** places;
  return Math.round(value * scale) / scale;
}

const cadences = new WeakMap();

function frameCadence(analysis) {
  if (analysis && typeof analysis === 'object' && cadences.has(analysis)) return cadences.get(analysis);
  const cadence = measureCadence(analysis);
  if (analysis && typeof analysis === 'object') cadences.set(analysis, cadence);
  return cadence;
}

function measureCadence(analysis) {
  const frames = Array.isArray(analysis?.frames) ? analysis.frames : [];
  const differences = [];
  for (let index = 1; index < frames.length; index += 1) {
    const difference = frames[index].time - frames[index - 1].time;
    if (difference > 0) differences.push(difference);
  }
  differences.sort((left, right) => left - right);
  return differences.length ? differences[Math.floor(differences.length / 2)] : 0.25;
}

export function mappedVocalCollision(outgoing, incoming, mapping = {}) {
  const duration = Math.max(0, finite(mapping.durationSeconds) ?? 0);
  const outgoingStart = finite(mapping.outgoingStart) ?? 0;
  const incomingStart = finite(mapping.incomingStart) ?? 0;
  const outgoingRatio = finite(mapping.outgoingRatio) ?? 1;
  const incomingRatio = finite(mapping.incomingRatio) ?? 1;
  const targetBpm = finite(mapping.targetBpm) ?? 0;
  const step = Math.max(0.05, Math.min(0.25, frameCadence(outgoing), frameCadence(incoming)));
  const sampleCount = Math.max(1, Math.ceil(duration / step) + 1);
  let known = 0;
  let simultaneousTotal = 0;
  let active = 0;
  let currentRun = 0;
  let longestRun = 0;
  for (let index = 0; index < sampleCount; index += 1) {
    const time = Math.min(duration, index * step);
    const offsets = mapping.tempoRamp
      ? glideOffsets(time, duration, outgoingRatio, incomingRatio)
      : { outgoing: time * outgoingRatio, incoming: time * incomingRatio };
    const outgoingVocal = interpolateTrackFrame(
      outgoing,
      'vocal',
      outgoingStart + offsets.outgoing
    );
    const incomingVocal = interpolateTrackFrame(
      incoming,
      'vocal',
      incomingStart + offsets.incoming
    );
    if (outgoingVocal === null || incomingVocal === null) {
      currentRun = 0;
      continue;
    }
    known += 1;
    simultaneousTotal += Math.min(outgoingVocal, incomingVocal);
    if (outgoingVocal >= VOCAL_ACTIVE_THRESHOLD && incomingVocal >= VOCAL_ACTIVE_THRESHOLD) {
      active += 1;
      currentRun += 1;
      longestRun = Math.max(longestRun, currentRun);
    } else {
      currentRun = 0;
    }
  }
  const longestRunSeconds = Math.min(duration, longestRun * step);
  return {
    simultaneousMean: known ? rounded(simultaneousTotal / known) : null,
    activeFraction: known ? rounded(active / known) : null,
    longestRunSeconds: rounded(longestRunSeconds),
    longestRunBeats: targetBpm > 0 ? rounded(longestRunSeconds * targetBpm / 60) : 0,
    coverage: rounded(known / sampleCount)
  };
}
