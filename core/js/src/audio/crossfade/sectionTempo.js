/* Copyright (C) 2026 SFG545. Licensed under the Orchard-Only License (OOL-1.0), see LICENSE-OOL. */

// Tempo of the section around a cue; songs drift, slow down or switch sections.
import { tempoFit } from './pairTempoHarmony.js';

function finite(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function rounded(value, places = 6) {
  const scale = 10 ** places;
  return Math.round(value * scale) / scale;
}

// Fewest beats a section tempo is fitted over; 16-beat fits on steady songs sit within 0.3%.
const SECTION_BEATS = 16;
// A section further than this from the song tempo runs at its own tempo. On real pairs,
// steady sections read within 2.7% (swing and the tracker's first bars) and drifting ones 4.4%+.
const SECTION_TOLERANCE = 0.035;
// Half-window fits of a steady section agree within this (4.6% worst seen); moving ones differ 10%+.
const STEADY_TOLERANCE = 0.06;

// Seconds per beat over `beats`, numbered by gap so a dropped beat keeps its place.
function beatSlope(beats, interval) {
  const numbers = [0];
  for (let index = 1; index < beats.length; index += 1) {
    numbers.push(numbers[index - 1] + Math.max(1, Math.round((beats[index] - beats[index - 1]) / interval)));
  }
  const meanNumber = numbers.reduce((sum, value) => sum + value, 0) / numbers.length;
  const meanTime = beats.reduce((sum, value) => sum + value, 0) / beats.length;
  let covariance = 0;
  let variance = 0;
  numbers.forEach((number, index) => {
    covariance += (number - meanNumber) * (beats[index] - meanTime);
    variance += (number - meanNumber) ** 2;
  });
  return variance > 0 ? covariance / variance : null;
}

/**
 * Tempo the listener hears over `from..to`, padded to SECTION_BEATS: the song tempo when the
 * section agrees with it, the section's own when it holds a different one, null when it moves.
 */
export function sectionBpm(analysis, from, to) {
  const bpm = finite(analysis?.timing?.bpm);
  const beats = analysis?.timing?.beats || [];
  if (!(bpm > 0)) return null;
  const interval = 60 / bpm;
  let first = beats.findIndex((time) => time >= from - interval / 2);
  let last = beats.findLastIndex((time) => time <= to + interval / 2);
  if (first < 0 || last < first) return bpm;
  const missing = SECTION_BEATS - (last - first);
  if (missing > 0) {
    first = Math.max(0, first - missing);
    last = Math.min(beats.length - 1, first + SECTION_BEATS);
  }
  const window = beats.slice(first, last + 1);
  // Too few beats to judge; the song tempo is the better guess.
  if (window.length < SECTION_BEATS / 2 + 1) return bpm;
  const slope = beatSlope(window, interval);
  if (!(slope > 0)) return null;
  if (Math.abs(interval / slope - 1) <= SECTION_TOLERANCE) return bpm;
  const middle = Math.floor(window.length / 2);
  const early = beatSlope(window.slice(0, middle + 1), interval);
  const late = beatSlope(window.slice(middle), interval);
  if (!(early > 0) || !(late > 0) || Math.abs(early / late - 1) > STEADY_TOLERANCE) return null;
  return rounded(60 / slope);
}

/** True when a span's section tempo matches the native tempo its cue was fitted with. */
export function holdsTempo(analysis, from, to, bpm) {
  const span = sectionBpm(analysis, from, to);
  return span !== null && bpm > 0 && Math.abs(span / bpm - 1) <= SECTION_TOLERANCE;
}

/**
 * Fit from the sections around two cues. A side whose tempo moves cannot be beatmatched,
 * so the pair keeps native speed like any unmatched pair.
 */
export function cueTempoFit(outgoing, incoming, outgoingAnchor, incomingAnchor, options = {}) {
  const left = sectionBpm(outgoing, outgoingAnchor, outgoingAnchor);
  const right = sectionBpm(incoming, incomingAnchor, incomingAnchor);
  if (left !== null && right !== null) return { ...tempoFit(left, right, options), sections: [left, right] };
  const fit = tempoFit(outgoing?.timing?.bpm, incoming?.timing?.bpm);
  return {
    ...fit,
    targetBpm: fit.outgoingBpm,
    outgoingRatio: 1,
    incomingRatio: 1,
    beatmatched: false,
    movingTempo: true
  };
}
