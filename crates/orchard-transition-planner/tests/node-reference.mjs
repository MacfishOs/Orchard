/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

import { mobileTransitionCases } from './mobileTransitionPlanner.js';
import { invoke } from '../js/index.js';
process.stdout.write(JSON.stringify(mobileTransitionCases.flatMap(({ name, input }) => {
  const value = { ...input, nextDuration: input.nextTrack.durationSeconds };
  return ['native', 'live'].map(method => ({ name, method, input: value,
    expected: JSON.parse(invoke(method, JSON.stringify(value))) }));
})));
