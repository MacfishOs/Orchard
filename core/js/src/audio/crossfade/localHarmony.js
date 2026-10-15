/* Copyright (C) 2026 SFG545. Licensed under the Orchard-Only License (OOL-1.0), see LICENSE-OOL. */

// Key compatibility where two songs actually overlap, from measured chroma.
// Calibration on 40 songs, 16 s windows against their own transpositions: the same key
// correlates +1, a fifth +0.40, a whole tone +0.16, a minor third -0.10, a major third -0.28,
// a semitone -0.36 and a tritone -0.63. Unrelated songs average +0.02.
import { chromaProfile } from '../../../shared/trackAnalysis.js';

// Profile contrast (peak over mean) where a window is plainly tonal; drum-only windows sit near 1.2.
const TONAL_FLOOR = 1.3;
const TONAL_SPAN = 0.4;
// Correlation of a semitone, tritone or major third apart; both sides must be clearly tonal.
export const CLASH_CORRELATION = -0.3;
export const CLASH_CONFIDENCE = 0.5;
// Seconds of each song read around the meeting point. Shorter windows read the passing chord;
// two songs in one key on different chords are compatible, so the key needs the wider view.
const KEY_CONTEXT_SECONDS = 24;

function clamp(value, minimum = 0, maximum = 1) {
  return Number.isFinite(value) ? Math.max(minimum, Math.min(maximum, value)) : minimum;
}

function rounded(value) {
  return Math.round(value * 1e6) / 1e6;
}

function pearson(left, right) {
  const meanLeft = left.reduce((sum, value) => sum + value, 0) / left.length;
  const meanRight = right.reduce((sum, value) => sum + value, 0) / right.length;
  let covariance = 0;
  let leftPower = 0;
  let rightPower = 0;
  for (let index = 0; index < left.length; index += 1) {
    const a = left[index] - meanLeft;
    const b = right[index] - meanRight;
    covariance += a * b;
    leftPower += a * a;
    rightPower += b * b;
  }
  return leftPower > 0 && rightPower > 0 ? covariance / Math.sqrt(leftPower * rightPower) : 0;
}

/** How plainly a side carries pitch: profile contrast times its tonal weight. */
function tonality(side) {
  const total = side.profile.reduce((sum, value) => sum + value, 0);
  if (!(total > 0)) return 0;
  const contrast = Math.max(...side.profile) / (total / 12);
  return clamp((contrast - TONAL_FLOOR) / TONAL_SPAN) * clamp(side.weight);
}

/**
 * Harmonic evidence for one overlap, or null without measured chroma on both sides.
 * Score is 0.5 when either side is untonal, so drums over chords never read as a clash.
 */
export function overlapHarmony(outgoing, incoming, pair) {
  const left = chromaProfile(outgoing, Math.min(pair.outgoingStart, pair.outgoingEnd - KEY_CONTEXT_SECONDS),
    pair.outgoingEnd);
  const right = chromaProfile(incoming, pair.incomingStart,
    Math.max(pair.incomingEnd, pair.incomingStart + KEY_CONTEXT_SECONDS));
  if (!left || !right) return null;
  const confidence = Math.min(tonality(left), tonality(right));
  const correlation = pearson(left.profile, right.profile);
  return {
    score: rounded(clamp(0.5 + 0.5 * correlation * confidence)),
    confidence: rounded(confidence),
    correlation: rounded(correlation),
    keyScore: null,
    chromaScore: rounded(correlation),
    source: 'local',
    severeClash: correlation <= CLASH_CORRELATION && confidence >= CLASH_CONFIDENCE
  };
}
