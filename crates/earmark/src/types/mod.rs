/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */
//! Data types shared across the analysis, planning, and rendering stages.

pub mod analysis;
pub mod beat;
pub mod diagnostics;
pub mod transition;

pub use analysis::{FeatureTrack, FrameFeatures, LoudnessStats, RegionFeatures};
pub use beat::BeatAnalysis;
pub use diagnostics::{Candidate, CandidateScore, ScoredCandidate, TransitionDiagnostics};
pub use transition::{
    FULL_SPAN, FadePlan, FilterPlan, MAX_RAMPED_TEMPO_RATIO_DEVIATION, MAX_SELECTED_TEMPO_RATIO_DEVIATION,
    SelectedTransition, TempoGlide, TransitionOutput, TransitionPlan, TransitionStrategy,
};
