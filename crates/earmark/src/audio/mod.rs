/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */
//! PCM storage and the two sample-domain conversions the engine needs.

pub mod buffer;
pub mod resample;
pub mod stretch;

pub use buffer::AudioBuffer;
