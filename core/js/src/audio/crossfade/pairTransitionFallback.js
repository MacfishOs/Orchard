/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

// The boundary plans a refusal falls back to.
import { BOUNDARY_ARRANGEMENT } from './transitionArrangement.js';
import { renderModeFor } from './pairTransitionGates.js';

function finite(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function rounded(value, places = 6) {
  const scale = 10 ** places;
  return Math.round(value * scale) / scale;
}

export function fallbackFor(outgoing, incoming, evaluation = null, reason = '') {
  const outgoingRange = outgoing.audibleRange || { start: 0, end: outgoing.duration || 0 };
  const incomingRange = incoming.audibleRange || { start: 0, end: incoming.duration || 0 };
  // Fallbacks never overlap: a silence trim advances at the measured end of audible
  // content, and anything else lets the media reach its ordinary end.
  const selectedClass = evaluation?.transitionClass === 'silence_trim' ? 'silence_trim' : 'normal_boundary';
  const outgoingEnd = selectedClass === 'silence_trim'
    ? outgoingRange.end
    : Math.max(outgoingRange.end, finite(outgoing.duration) ?? 0);
  return {
    transitionClass: selectedClass,
    outgoingStart: rounded(outgoingEnd),
    outgoingEnd: rounded(outgoingEnd),
    incomingCue: rounded(incomingRange.start),
    durationSeconds: 0,
    strategy: 'boundary_handoff',
    transitionStyle: selectedClass,
    reason
  };
}

/** A refusal reports the geometry that actually plays: no overlap. */
export function fallbackPlan(outgoing, incoming, generated, reason, explain = null, {
  evaluation = null, confidence = 0, diagnostics = null
} = {}) {
  const fallback = fallbackFor(outgoing, incoming, evaluation, reason);
  return {
    status: 'fallback',
    transitionClass: fallback.transitionClass,
    renderMode: renderModeFor(fallback.transitionClass),
    outgoing: {
      start: fallback.outgoingStart,
      end: fallback.outgoingEnd,
      tempoRatio: 1
    },
    incoming: {
      start: fallback.incomingCue,
      handoff: fallback.incomingCue,
      resume: fallback.incomingCue,
      tempoRatio: 1
    },
    durationSeconds: fallback.durationSeconds,
    beats: 0,
    targetBpm: 0,
    phase: { beatErrorSeconds: null, downbeatAligned: false },
    strategy: fallback.strategy,
    technique: BOUNDARY_ARRANGEMENT.technique,
    arrangement: BOUNDARY_ARRANGEMENT,
    rendering: {
      fade: fallback.transitionStyle,
      bassHandoff: false,
      filters: false,
      vocalDuckCurve: []
    },
    confidence,
    fallbackReason: reason,
    explain,
    fallback,
    diagnostics: diagnostics ?? {
      generated,
      reasonCounts: { [reason]: 1 },
      topCandidates: [],
      selected: null,
      winnerMargin: 0
    }
  };
}
