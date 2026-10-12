/* Copyright (C) 2026 SFG545. Licensed under the Orchard-Only License (OOL-1.0), see LICENSE-OOL. */

//! Orchard's Android native library. Adaptive mixes and Best Mix run the desktop worker's own
//! Rust (`mix`); the QuickJS provider host resolves YouTube player code through the extractor.
//! A rule that lives here rather than in a shared crate is a rule only Android obeys.

// The QuickJS provider host resolves these by name from this library.
pub use orchard_youtube_extractor::ffi::{orchard_youtube_extract, orchard_youtube_extract_free};

mod mix;
