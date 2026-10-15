/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */
use serde_json::json;

#[test]
fn queue_session_matches_isolated_pair_planner() {
    let input = json!({
        "analysis": {"duration": 150, "bpm": 140, "key": "C major"},
        "nextAnalysis": {"duration": 145, "bpm": 138, "key": "A minor"},
        "duration": 150, "nextDuration": 145
    });
    let expected = orchard_transition_planner::invoke("native", &input).unwrap();
    let mut session = orchard_transition_planner::PlannerSession::new().unwrap();
    assert_eq!(session.invoke("native", &input).unwrap(), expected);
    assert_eq!(session.invoke("native", &input).unwrap(), expected);
}
