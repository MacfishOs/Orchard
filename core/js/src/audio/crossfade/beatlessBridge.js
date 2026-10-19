/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

// Beatless bridge: the old song's beatless outro under the new song's beatless intro, so no beat
// ever plays against another and the tempos need not match. The new beat lands as the old song
// finishes. Listening rounds kept beatless-into-beatless (The Weekend -> Jump) and rejected
// beatless outros fading into a beat, so both sides stay beatless for the whole overlap.
import { beatPresence, incomingVoiceRisk, STYLE_CLASH_CONTRAST } from './transitionFlow.js';
import { mappedVocalCollision } from './vocalCollision.js';
import { overlapHarmony } from './localHarmony.js';

// Beat presence under which a passage carries no kick or bassline.
const BEATLESS = 0.3;
const STEP = 0.25;
const MIN_SECONDS = 4;
const MAX_SECONDS = 12;
// Beatless intro the bridge may skip so the new beat lands as the old song ends.
const MAX_SKIP_SECONDS = 16;
// Seconds kept between the handoff and the end of the decoded incoming window.
const WINDOW_MARGIN = 0.25;
// Nominal grid for songs without a tempo; the bridge has no beat to match.
const NOMINAL_BPM = 120;
const SUSTAINED_VOICE_BEATS = 4;

function rounded(value) {
  return Math.round(value * 1e6) / 1e6;
}

function finite(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

/** Seconds of unbroken beatless audio from `from`, walking by `step` (negative walks back). */
function beatlessRun(analysis, from, limit, step) {
  let run = 0;
  for (let time = from; step > 0 ? time < limit : time > limit; time += step) {
    const presence = beatPresence(analysis, time);
    if (presence === null || presence >= BEATLESS) break;
    run += Math.abs(step);
  }
  return run;
}

function refuse(code, detail) {
  return { ok: false, code, detail };
}

/**
 * A bridge over the two songs' beatless edges, or a refusal saying why there is none.
 * The outgoing plays to its natural end, so nothing is cut short.
 */
export function planBeatlessBridge(outgoing, incoming, {
  outgoingWindowStart = null, incomingWindowEnd = null, contrast = null
} = {}) {
  if (!outgoing.curves?.bass || !incoming.curves?.bass) return refuse('bridge-unmeasured', 'no bass curves');
  if (contrast !== null && contrast >= STYLE_CLASH_CONTRAST) {
    return refuse('style-contrast', 'the productions clash');
  }
  const end = outgoing.audibleRange.end;
  const earliest = Math.max(outgoing.audibleRange.start, finite(outgoingWindowStart) ?? -Infinity);
  const outgoingRun = beatlessRun(outgoing, end - STEP / 2, Math.max(earliest, end - MAX_SECONDS), -STEP);
  const start = incoming.audibleRange.start;
  const latest = Math.min(incoming.audibleRange.end, (finite(incomingWindowEnd) ?? Infinity) - WINDOW_MARGIN);
  const incomingRun = beatlessRun(incoming, start + STEP / 2, latest, STEP);
  if (Math.min(outgoingRun, incomingRun) < MIN_SECONDS) {
    return refuse('no-beatless-edge', `beatless outro ${outgoingRun} s, intro ${incomingRun} s`);
  }
  const bpm = finite(outgoing.timing?.bpm) > 0 ? outgoing.timing.bpm : NOMINAL_BPM;
  const beat = 60 / bpm;
  // A whole number of the outgoing's beats keeps the exact-render contract.
  const beats = Math.floor(Math.min(outgoingRun, incomingRun, MAX_SECONDS) / beat);
  const durationSeconds = rounded(beats * beat);
  if (durationSeconds < MIN_SECONDS) return refuse('no-beatless-edge', 'beatless edges too short');
  const skip = Math.min(Math.max(0, incomingRun - durationSeconds), MAX_SKIP_SECONDS);
  const pair = {
    outgoingStart: rounded(end - durationSeconds),
    outgoingEnd: rounded(end),
    incomingStart: rounded(start + skip),
    incomingEnd: rounded(start + skip + durationSeconds),
    durationSeconds,
    beats,
    targetBpm: bpm,
    outgoingRatio: 1,
    incomingRatio: 1
  };
  const collision = mappedVocalCollision(outgoing, incoming, { ...pair, targetBpm: bpm });
  if ((collision.longestRunBeats ?? 0) >= SUSTAINED_VOICE_BEATS || (collision.simultaneousMean ?? 0) > 0.25) {
    return refuse('voice-over-voice', `voices meet over the bridge (${collision.simultaneousMean})`);
  }
  const voice = incomingVoiceRisk(pair, incoming);
  if ((voice ?? 0) >= 0.5) return refuse('voice-cut', 'the new song would fade in mid-line');
  const harmony = overlapHarmony(outgoing, incoming, pair);
  if (harmony?.severeClash) return refuse('harmonic-clash', `the keys clash (${harmony.correlation})`);
  // Untonal or unmeasured overlaps sit at the conservative floor; agreeing keys rise above it.
  const confidence = rounded(0.62 + 0.2 * ((harmony?.score ?? 0.5) - 0.5));
  return { ok: true, pair, collision, harmony, voice, skip: rounded(skip), confidence };
}
