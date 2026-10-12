/* Copyright (C) 2026 SFG545. Licensed under the Orchard-Only License (OOL-1.0), see LICENSE-OOL. */

use serde_json::Value;
use std::process::Command;

fn compare(actual: &Value, expected: &Value, path: &str) {
    match (actual, expected) {
        (Value::Number(a), Value::Number(b)) => {
            let (a, b) = (a.as_f64().unwrap(), b.as_f64().unwrap());
            assert!((a - b).abs() <= 1e-9 * b.abs().max(1.0), "{path}: {a} != {b}");
        }
        (Value::Array(a), Value::Array(b)) => {
            assert_eq!(a.len(), b.len(), "{path}");
            for (i, (a, b)) in a.iter().zip(b).enumerate() { compare(a, b, &format!("{path}[{i}]")); }
        }
        (Value::Object(a), Value::Object(b)) => {
            assert_eq!(a.len(), b.len(), "{path}");
            for (key, b) in b { compare(a.get(key).unwrap_or_else(|| panic!("{path}.{key} missing")), b, &format!("{path}.{key}")); }
        }
        _ => assert_eq!(actual, expected, "{path}"),
    }
}

#[test]
fn quickjs_matches_mobile_entry_on_all_mobile_fixtures() {
    let output = Command::new("node").arg(concat!(env!("CARGO_MANIFEST_DIR"), "/tests/node-reference.mjs"))
        .output().expect("Node is needed for the independent planner parity reference");
    assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
    let cases: Vec<Value> = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(cases.len(), 264);
    for case in cases {
        let method = case["method"].as_str().unwrap();
        let result = orchard_transition_planner::invoke(method, &case["input"])
            .unwrap_or_else(|e| panic!("{} {method}: {e}", case["name"]));
        compare(&result, &case["expected"], &format!("{} {method}", case["name"]));
    }
}
