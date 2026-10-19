/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */

//! Best Mix queue analysis and ordering. The queue worker never initializes GPU models.
use crate::{best_mix_cost::number, evidence, song::{ANALYSIS_RATE, Track, WINDOW}};
pub use crate::best_mix_order::{sort, sort_lazy};
use earmark::{WholeTrackAnalysis, WholeTrackAnalyzer};
use serde_json::{Value, json};

/// The part of a `{start, step, values}` curve inside `span`.
fn curve_span(curve: &Value, span: (f64, f64)) -> Value {
    let (start, step) = (number(curve, "start"), number(curve, "step"));
    let values = curve["values"].as_array().map(Vec::as_slice).unwrap_or_default();
    if step <= 0.0 { return Value::Null; }
    let first = (((span.0 - start) / step).floor().max(0.0) as usize).min(values.len());
    let last = (((span.1 - start) / step).ceil().max(0.0) as usize).clamp(first, values.len());
    json!({"start": start + first as f64 * step, "step": step, "values": &values[first..last]})
}

/// One mix edge: whole-song tempo, key, loudness and 808 weight, with timed evidence cut to `span`.
fn edge(value: &WholeTrackAnalysis, sub_bass: Option<f64>, bass: &Value, span: (f64, f64)) -> Value {
    let within = |time: f64| time >= span.0 && time <= span.1;
    json!({
        // Same local harmony evidence as playback.
        "chromaCurve": evidence::chroma_curve(&value.chroma_frames, span),
        "duration": value.duration, "bpm": value.bpm, "beatConfidence": value.beat_confidence,
        "tempoConfidence": value.beat_confidence, "key": value.key,
        "keyConfidence": value.key_confidence, "chroma": value.chroma,
        "loudnessLufs": value.loudness_lufs,
        // Whole-song production weight; the planner's style-clash gate compares it.
        "subBassRatio": sub_bass,
        // Same DSP curve as playback, so finalists see beat flow, beat entries and bass swaps.
        "bassCurve": curve_span(bass, span),
        // Spectral estimate, same as playback analysis. The planner treats it as risk only.
        "vocalProbability": value.vocal_probability,
        "beats": value.beats.iter().copied().filter(|t| within(*t)).collect::<Vec<_>>(),
        "downbeats": value.downbeats.iter().copied().filter(|t| within(*t)).collect::<Vec<_>>(),
        "beatInterval": value.beat_interval,
        "audibleStartTime": value.audible_start_time,
        "contentEndTime": value.content_end_time,
        "pickupConfidence": value.pickup_confidence,
        "energyCurve": value.energy_curve.iter().filter(|p| within(p.time))
            .map(|p| json!({"time":p.time,"energy":p.energy})).collect::<Vec<_>>(),
        "transitionFeatureFrames": value.transition_feature_frames.iter().filter(|f| within(f.time)).map(|f| json!({
            "time": f.time, "energy": f.energy, "low": f.low, "mid": f.mid,
            "high": f.high, "vocal": f.vocal, "novelty": f.novelty,
            "transientDensity": f.transient_density, "stability": f.stability
        })).collect::<Vec<_>>(),
        "structuralBoundaryCandidates": value.structural_boundary_candidates.iter().filter(|b| within(b.time)).map(|b| json!({
            "time": b.time, "observedTime": b.observed_time,
            "confidence": b.confidence, "source": b.source, "noveltyPeak": b.novelty_peak,
            "energyDelta": b.energy_delta, "lowDelta": b.low_delta,
            "vocalDelta": b.vocal_delta, "stabilityBefore": b.stability_before,
            "stabilityAfter": b.stability_after, "downbeatDistance": b.downbeat_distance
        })).collect::<Vec<_>>()
    })
}

/// Whole-song analysis of a downloaded saver file.
#[cfg(feature = "desktop")]
pub fn analyze(path: &str, duration: f64) -> Result<Value, String> {
    analyze_track(&crate::decode::local_song(path)?.track, duration)
}

/// Whole-song analysis, as V2 measured it. Windows alone misread tempo by 3:2 and
/// flatten key detection, and one bad intro should not DJ the entire queue.
/// Returns full `head`/`tail` edges for planning and compact summaries for the shortlist.
pub fn analyze_track(track: &Track, duration: f64) -> Result<Value, String> {
    if !duration.is_finite() || !(2.0..=7200.0).contains(&duration) {
        return Err("Invalid song duration".into());
    }
    // Saver files are complete; a large gap means a truncated or mismatched download.
    if (track.duration - duration).abs() > duration.max(10.0) * 0.1 {
        return Err("Analysis file does not match the song".into());
    }
    let value = WholeTrackAnalyzer::new().map_err(|e| e.to_string())?
        .analyze(&track.mono, ANALYSIS_RATE as f64, track.duration)
        .map_err(|e| e.to_string())?;
    let sub_bass = evidence::sub_bass_ratio(&track.mono, ANALYSIS_RATE);
    let bass = evidence::bass_curve(&track.mono, ANALYSIS_RATE);
    let end = value.duration;
    let head = edge(&value, sub_bass, &bass, (0.0, end.min(WINDOW)));
    let tail = edge(&value, sub_bass, &bass, ((end - WINDOW).max(0.0), end));
    Ok(json!({"headSummary": summary(&head, false), "tailSummary": summary(&tail, true),
              "head": head, "tail": tail}))
}

/// Shortlist fields of an edge; the energy curve shrinks to the mean the shortlist reads, the
/// chroma to the mixable part's profile, the bass curve to its beatless seconds.
fn summary(edge: &Value, tail: bool) -> Value {
    let mut compact = serde_json::Map::new();
    for key in ["duration", "bpm", "beatConfidence", "tempoConfidence", "key", "keyConfidence",
                "loudnessLufs", "vocalProbability", "subBassRatio"] {
        compact.insert(key.into(), edge[key].clone());
    }
    if let Some(mean) = energy(edge, tail) {
        compact.insert("energyCurve".into(), json!([{"energy": mean}]));
    }
    if let Some(chroma) = edge_chroma(edge, tail) {
        compact.insert("chroma".into(), json!(chroma));
    }
    compact.insert("beatlessEdge".into(), json!(beatless_edge(edge, tail)));
    Value::Object(compact)
}

fn energy(edge: &Value, from_end: bool) -> Option<f64> {
    let points = edge["energyCurve"].as_array()?;
    if points.is_empty() {
        return None;
    }
    let count = ((points.len() as f64 * 0.08).ceil() as usize)
        .clamp(2, 6)
        .min(points.len());
    let slice = if from_end {
        &points[points.len() - count..]
    } else {
        &points[..count]
    };
    Some(slice.iter().map(|p| number(p, "energy")).sum::<f64>() / count as f64)
}

/// Seconds a summary's chroma covers: the end of a tail or the start of a head, where mixes sit.
const MIX_SPAN: f64 = 30.0;
/// Bass curve level (1 = the song's usual low end) under which a passage carries no beat.
const BEATLESS_LEVEL: f64 = 0.22;
/// Longest beatless edge worth measuring; bridges use 12 s at most.
const MAX_BEATLESS: f64 = 12.0;

/// Tonal-weighted pitch-class profile over the mixable part of an edge.
fn edge_chroma(edge: &Value, tail: bool) -> Option<Vec<f64>> {
    let curve = &edge["chromaCurve"];
    let (start, step) = (number(curve, "start"), number(curve, "step"));
    let values = curve["values"].as_array()?;
    let weights = curve["weights"].as_array()?;
    let end = start + step * values.len() as f64;
    let (from, to) = if tail { (end - MIX_SPAN, end) } else { (start, start + MIX_SPAN) };
    let mut profile = vec![0.0; 12];
    for (index, frame) in values.iter().enumerate() {
        let time = start + index as f64 * step;
        if time < from || time >= to {
            continue;
        }
        let weight = weights.get(index).and_then(Value::as_f64).unwrap_or(1.0);
        for (slot, value) in profile.iter_mut().zip(frame.as_array()?) {
            *slot += value.as_f64().unwrap_or(0.0) * weight;
        }
    }
    let total: f64 = profile.iter().sum();
    (total > 0.0).then(|| profile.iter().map(|value| (value / total * 1000.0).round() / 1000.0).collect())
}

/// Seconds of beatless audio at the song's end (tail) or start (head), from the bass curve.
fn beatless_edge(edge: &Value, tail: bool) -> f64 {
    let curve = &edge["bassCurve"];
    let (start, step) = (number(curve, "start"), number(curve, "step"));
    let Some(values) = curve["values"].as_array() else { return 0.0 };
    if step <= 0.0 {
        return 0.0;
    }
    let level = |time: f64| values.get(((time - start) / step).floor().max(0.0) as usize).and_then(Value::as_f64);
    let (origin, direction) = if tail { (number(edge, "contentEndTime") - step / 2.0, -step) }
        else { (number(edge, "audibleStartTime") + step / 2.0, step) };
    let mut seconds = 0.0;
    while seconds < MAX_BEATLESS {
        match level(origin + direction * (seconds / step)) {
            Some(value) if value < BEATLESS_LEVEL => seconds += step,
            _ => break,
        }
    }
    seconds
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn edge_curves_keep_track_time() {
        let curve = json!({"start": 0.0, "step": 0.25, "values": [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]});
        assert_eq!(curve_span(&curve, (0.5, 1.0)),
                   json!({"start": 0.5, "step": 0.25, "values": [0.2, 0.3]}));
        assert_eq!(curve_span(&curve, (9.0, 10.0))["values"], json!([]));
    }

    #[test]
    fn summaries_carry_the_mixable_chroma_and_beatless_edges() {
        let frames: Vec<Value> = (0..120).map(|i| {
            let mut frame = vec![0.0; 12];
            frame[if i < 60 { 0 } else { 7 }] = 1.0;
            json!(frame)
        }).collect();
        let bass: Vec<f64> = (0..240).map(|i| if i >= 220 { 0.05 } else { 1.0 }).collect();
        let edge = json!({"chromaCurve": {"start": 0.0, "step": 0.5, "values": frames, "weights": vec![1.0; 120]},
            "bassCurve": {"start": 0.0, "step": 0.25, "values": bass}, "contentEndTime": 60.0,
            "audibleStartTime": 0.0});
        let tail = summary(&edge, true);
        assert_eq!(tail["chroma"][7], json!(1.0));
        assert_eq!(tail["beatlessEdge"], json!(5.0));
        let head = summary(&edge, false);
        assert_eq!(head["chroma"][0], json!(1.0));
        assert_eq!(head["beatlessEdge"], json!(0.0));
    }
}
