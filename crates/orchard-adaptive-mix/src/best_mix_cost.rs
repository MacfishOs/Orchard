/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

//! Best Mix pair costs. The cheap prediction mirrors the shared planner's hard gates, so a pair
//! predicted to beatmatch is one playback can beatmatch; verified costs come from the planner.
use serde_json::Value;

/// MAX_RAMP_DEVIATION in pairTempoHarmony.js.
const MAX_TEMPO_DEVIATION: f64 = 0.08;
/// STYLE_CLASH_CONTRAST in transitionFlow.js.
const STYLE_CLASH: f64 = 0.9;
/// CLASH_CORRELATION and CLASH_CONFIDENCE in localHarmony.js.
const CLASH_CORRELATION: f64 = -0.3;
const CLASH_TONALITY: f64 = 0.5;
/// MIN_SECONDS in beatlessBridge.js.
const MIN_BRIDGE_SECONDS: f64 = 4.0;

/// One cost scale for predicted and planned pairs: any mix outranks a play-out, any beatmatch a
/// bridge. Quality terms add at most about 3.
pub const PLAY_OUT: f64 = 20.0;
pub const BRIDGE: f64 = 8.0;
pub const CONSERVATIVE: f64 = 4.0;
/// Expected cost of a beatmatch predicted from summaries: on 127 benchmark pairs 72% planned as
/// conservative mixes, 4% as bridges and 24% played out. Pricing it this way keeps planned
/// pairs ahead of unplanned guesses, so the search converges on pairs it has checked.
pub const UNVERIFIED: f64 = 9.0;
/// Predicted bridges carry the same play-out risk on top of the bridge cost.
const UNVERIFIED_BRIDGE: f64 = 12.0;
/// Logistic fit of playback mixing a pair the queue planner accepted, against that plan's
/// confidence: 51% below 0.70, 83% at 0.70-0.75, 94% at 0.75-0.80 on 108 benchmark pairs.
/// Most misses are measured vocals the summaries cannot carry.
const PLAYBACK_CENTRE: f64 = 0.665;
const PLAYBACK_SPREAD: f64 = 0.035;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Kind {
    Beatmatch,
    Bridge,
    PlayOut,
}

pub fn number(value: &Value, key: &str) -> f64 {
    value[key].as_f64().unwrap_or(0.0)
}

/// Octave-folded tempo gap as the planner's glide measures it, or None without tempos.
pub fn tempo_deviation(left: f64, right: f64) -> Option<f64> {
    if left <= 0.0 || right <= 0.0 {
        return None;
    }
    let mut ratio = right / left;
    while ratio > 1.5 {
        ratio /= 2.0;
    }
    while ratio < 0.67 {
        ratio *= 2.0;
    }
    Some((ratio - 1.0).abs().max((1.0 / ratio - 1.0).abs()))
}

fn profile(edge: &Value) -> Option<[f64; 12]> {
    let values = edge["chroma"].as_array()?;
    if values.len() != 12 {
        return None;
    }
    let mut profile = [0.0; 12];
    for (slot, value) in profile.iter_mut().zip(values) {
        *slot = value.as_f64()?.max(0.0);
    }
    (profile.iter().sum::<f64>() > 0.0).then_some(profile)
}

/// Contrast of a profile mapped as localHarmony.js maps it: 0 for drums, 1 for plain chords.
fn tonality(profile: &[f64; 12]) -> f64 {
    let mean = profile.iter().sum::<f64>() / 12.0;
    let peak = profile.iter().copied().fold(0.0, f64::max);
    ((peak / mean - 1.3) / 0.4).clamp(0.0, 1.0)
}

fn correlation(left: &[f64; 12], right: &[f64; 12]) -> f64 {
    let (mean_left, mean_right) = (left.iter().sum::<f64>() / 12.0, right.iter().sum::<f64>() / 12.0);
    let (mut covariance, mut left_power, mut right_power) = (0.0, 0.0, 0.0);
    for (a, b) in left.iter().zip(right) {
        covariance += (a - mean_left) * (b - mean_right);
        left_power += (a - mean_left).powi(2);
        right_power += (b - mean_right).powi(2);
    }
    if left_power <= 0.0 || right_power <= 0.0 { 0.0 } else { covariance / (left_power * right_power).sqrt() }
}

/// Correlation and the weaker side's tonality where the songs would meet.
fn harmony(left: &Value, right: &Value) -> Option<(f64, f64)> {
    let (left, right) = (profile(left)?, profile(right)?);
    Some((correlation(&left, &right), tonality(&left).min(tonality(&right))))
}

fn energy(edge: &Value) -> Option<f64> {
    edge["energyCurve"].as_array()?.first()?["energy"].as_f64()
}

/// Expected transition and its cost from a tail summary into a head summary.
pub fn predict(left: &Value, right: &Value) -> (Kind, f64) {
    let contrast = left["subBassRatio"].as_f64().zip(right["subBassRatio"].as_f64())
        .map(|(a, b)| (a - b).abs());
    let harmony = harmony(left, right);
    // Clashing keys only refuse bridges; beatmatched blends keep to whole-song keys.
    let key_clash = harmony.is_some_and(|(r, tonal)| r <= CLASH_CORRELATION && tonal >= CLASH_TONALITY);
    let deviation = tempo_deviation(number(left, "bpm"), number(right, "bpm"));
    let bridge = number(left, "beatlessEdge") >= MIN_BRIDGE_SECONDS
        && number(right, "beatlessEdge") >= MIN_BRIDGE_SECONDS
        && !key_clash;
    let kind = if contrast.is_some_and(|value| value >= STYLE_CLASH) {
        Kind::PlayOut
    } else if deviation.is_some_and(|value| value <= MAX_TEMPO_DEVIATION) {
        Kind::Beatmatch
    } else if bridge {
        Kind::Bridge
    } else {
        Kind::PlayOut
    };
    let mut cost = match kind {
        Kind::Beatmatch => UNVERIFIED + deviation.unwrap_or(0.0) / MAX_TEMPO_DEVIATION * 0.5,
        Kind::Bridge => UNVERIFIED_BRIDGE,
        Kind::PlayOut => PLAY_OUT,
    };
    // Soft terms rank pairs within a kind; none can lift a pair across kinds.
    if let Some((r, tonal)) = harmony {
        cost += 0.5 - 0.5 * r * tonal;
    }
    if let Some(contrast) = contrast {
        cost += (contrast / STYLE_CLASH).min(1.0) * 0.4;
    }
    if let (Some(a), Some(b)) = (energy(left), energy(right)) {
        cost += ((a - b).abs() / 1.5).min(1.0) * 0.3;
    }
    if let (Some(a), Some(b)) = (left["loudnessLufs"].as_f64(), right["loudnessLufs"].as_f64())
        && a > -69.0 && b > -69.0
    {
        cost += ((a - b).abs() / 12.0).min(1.0) * 0.3;
    }
    let vocal = |edge: &Value| edge["vocalProbability"].as_f64().filter(|v| *v >= 0.0);
    if let (Some(a), Some(b)) = (vocal(left), vocal(right)) {
        cost += ((a - 0.5) * 2.0).clamp(0.0, 1.0) * ((b - 0.5) * 2.0).clamp(0.0, 1.0) * 0.35;
    }
    (kind, cost)
}

/// Expected cost of the transition the planner chose: its own cost if playback mixes it too,
/// a play-out if playback's measured vocals refuse it.
pub fn planned(plan: &Value) -> f64 {
    let pair = &plan["pairPlan"];
    let class = match pair["transitionClass"].as_str().unwrap_or("normal_boundary") {
        "full_beatmatched" => 0.0,
        "conservative_beatmatched" => CONSERVATIVE,
        "beatless_bridge" => BRIDGE,
        _ => return PLAY_OUT,
    };
    let confidence = number(pair, "confidence").clamp(0.0, 1.0);
    let quality = pair["diagnostics"]["selected"]["quality"].as_f64().unwrap_or(0.5);
    let mixed = class + (1.0 - confidence) * 2.0 + (1.0 - quality.clamp(0.0, 1.0));
    let likely = 1.0 / (1.0 + (-(confidence - PLAYBACK_CENTRE) / PLAYBACK_SPREAD).exp());
    likely * mixed + (1.0 - likely) * PLAY_OUT
}

/// True when the edge carries a tempo or key: something to mix on.
pub fn has_musical(edge: &Value) -> bool {
    number(edge, "bpm") > 0.0 || edge["key"].as_str().is_some_and(|key| !key.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    const C_MAJOR: [f64; 12] = [0.2, 0.01, 0.12, 0.01, 0.15, 0.1, 0.01, 0.18, 0.01, 0.12, 0.01, 0.08];

    fn rotated(semitones: usize) -> Vec<f64> {
        (0..12).map(|pitch| C_MAJOR[(pitch + 12 - semitones) % 12]).collect()
    }

    fn edge(bpm: f64, chroma: Vec<f64>) -> Value {
        json!({"bpm": bpm, "beatConfidence": 0.9, "chroma": chroma})
    }

    #[test]
    fn half_time_folds_and_an_8_percent_glide_still_beatmatches() {
        assert_eq!(predict(&edge(140.0, rotated(0)), &edge(70.0, rotated(7))).0, Kind::Beatmatch);
        assert_eq!(predict(&edge(100.0, rotated(0)), &edge(107.5, rotated(0))).0, Kind::Beatmatch);
        assert_eq!(predict(&edge(100.0, rotated(0)), &edge(112.0, rotated(0))).0, Kind::PlayOut);
    }

    #[test]
    fn beatless_edges_bridge_any_tempo_gap() {
        let mut left = edge(90.0, rotated(0));
        let mut right = edge(128.0, rotated(7));
        left["beatlessEdge"] = json!(8.0);
        right["beatlessEdge"] = json!(6.0);
        assert_eq!(predict(&left, &right).0, Kind::Bridge);
    }

    #[test]
    fn clashing_keys_refuse_bridges_and_clashing_productions_play_out() {
        assert_eq!(predict(&edge(120.0, rotated(0)), &edge(120.0, rotated(6))).0, Kind::Beatmatch);
        let mut left = edge(90.0, rotated(0));
        let mut right = edge(128.0, rotated(6));
        left["beatlessEdge"] = json!(8.0);
        right["beatlessEdge"] = json!(6.0);
        assert_eq!(predict(&left, &right).0, Kind::PlayOut);
        let mut trap = edge(140.0, rotated(0));
        let mut boom_bap = edge(140.0, rotated(0));
        trap["subBassRatio"] = json!(0.4);
        boom_bap["subBassRatio"] = json!(-0.6);
        assert_eq!(predict(&trap, &boom_bap).0, Kind::PlayOut);
    }

    #[test]
    fn related_keys_cost_less_than_distant_ones() {
        let left = edge(120.0, rotated(0));
        assert!(predict(&left, &edge(120.0, rotated(0))).1 < predict(&left, &edge(120.0, rotated(2))).1);
        // Unmeasured harmony keeps the tempo cost only.
        assert_eq!(predict(&json!({"bpm": 120.0}), &json!({"bpm": 120.0})).1, UNVERIFIED);
    }

    #[test]
    fn planned_costs_rank_sure_mixes_above_doubtful_ones_and_play_outs() {
        let plan = |class: &str, confidence: f64| json!({"pairPlan": {"transitionClass": class,
            "confidence": confidence, "diagnostics": {"selected": {"quality": confidence}}}});
        let order = [plan("full_beatmatched", 0.85), plan("conservative_beatmatched", 0.78),
            plan("beatless_bridge", 0.8), plan("conservative_beatmatched", 0.66), plan("normal_boundary", 1.0)];
        for pair in order.windows(2) {
            assert!(planned(&pair[0]) < planned(&pair[1]), "{} vs {}", planned(&pair[0]), planned(&pair[1]));
        }
        // A planned sure mix beats an unplanned guess; an unplanned guess beats a play-out.
        assert!(planned(&order[1]) < UNVERIFIED && UNVERIFIED < PLAY_OUT);
    }
}
