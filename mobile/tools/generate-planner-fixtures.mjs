/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { mobileTransitionCases } from '../../crates/orchard-transition-planner/tests/mobileTransitionPlanner.js';
import { planTransition } from '../../core/js/src/audio/crossfade/transitionPlanner.js';
import { planWsolaTransition } from '../../core/js/src/audio/crossfade/wsolaPlanner.js';
const output = path.resolve(process.argv[2]);
await mkdir(output, { recursive: true });
await writeFile(path.join(output, 'desktop-planner-fixtures.json'), JSON.stringify(mobileTransitionCases.map(({ name, input }) => ({
  name, input, live: planTransition(input), native: planWsolaTransition({
    analysis: input.analysis, nextAnalysis: input.nextAnalysis,
    duration: Math.max(input.duration, input.currentTrack.durationSeconds),
    nextDuration: input.nextTrack.durationSeconds
  })
}))));
