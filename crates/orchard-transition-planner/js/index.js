/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

// QuickJS entry for the desktop planner; caches pair decisions between ticks.
import { planTransition, transitionFromPairFallback } from '../../../core/js/src/audio/crossfade/transitionPlanner.js';
import { planWsolaTransition } from '../../../core/js/src/audio/crossfade/wsolaPlanner.js';

const MAX_CACHE_ENTRIES = 2;
const cache = new Map();
export function invoke(method, json) {
  const input = JSON.parse(json);
  input.currentTrack ||= {};
  input.nextTrack ||= {};
  const currentTime = Math.max(0, Number(input.currentTime) || 0);
  delete input.currentTime;
  const key = method + JSON.stringify(input);
  let plan = cache.get(key);
  if (!plan) {
    plan = method === 'native' ? planWsolaTransition(input) : planTransition(input);
    // One live and one native result cover the active pair; older pairs are never asked for again.
    if (cache.size >= MAX_CACHE_ENTRIES) cache.delete(cache.keys().next().value);
    cache.set(key, plan);
  }
  if (method === 'native') return JSON.stringify(plan);
  if (plan.pairPlan) {
    return JSON.stringify(transitionFromPairFallback(
      plan.pairPlan, input.analysis, input.nextAnalysis,
      Math.max(input.duration || 0, input.currentTrack?.durationSeconds || 0),
      currentTime
    ));
  }
  if (!plan.markerVisible) return JSON.stringify(plan);
  const shouldStart = currentTime >= plan.transitionStart;
  const reason = shouldStart
    ? plan.reason === 'before-gapless-window' ? 'same-album-gapless'
      : plan.reason.replace(/^before-/, '').replace(/-window$/, '')
    : plan.reason;
  return JSON.stringify({ ...plan, shouldStart, reason });
}
