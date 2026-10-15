/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

//! Opt-in hardware test: cargo test -p orchard-adaptive-mix --test models -- --ignored
use orchard_adaptive_mix::models::Models;

#[test]
#[ignore = "requires ONNX models and a hardware GPU; Beat This has no CPU fallback"]
fn beat_this_runs_on_webgpu_and_silence_does_not_invent_beats() {
    let models = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../models");
    let mut models = Models::new(&models).unwrap();
    let silence = vec![0.0f32; 44100 * 5];
    assert_eq!(
        models.beats(&silence).unwrap_err(),
        "Beat This found fewer than eight beats"
    );
}
