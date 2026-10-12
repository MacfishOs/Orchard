/* Copyright (C) 2026 SFG545. Licensed under the Orchard-Only License (OOL-1.0), see LICENSE-OOL. */

fn main() {
    let root = std::path::Path::new("../../third_party/quickjs");
    println!("cargo:rerun-if-changed={}", root.display());
    println!("cargo:rerun-if-changed=src/bridge.c");
    let mut build = cc::Build::new();
    build.include(root).file("src/bridge.c").define("_GNU_SOURCE", None)
        .define("QUICKJS_NG_BUILD", None).std("c11")
        .flag_if_supported("-funsigned-char").warnings(false);
    for source in ["quickjs.c", "dtoa.c", "libregexp.c", "libunicode.c"] {
        build.file(root.join(source));
    }
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        build.define("WIN32_LEAN_AND_MEAN", None).define("_WIN32_WINNT", "0x0601");
    }
    build.compile("orchard_planner_quickjs");
    if std::env::var("CARGO_CFG_UNIX").is_ok() {
        println!("cargo:rustc-link-lib=m");
        // Bionic keeps pthreads in libc; the NDK ships no libpthread to link.
        if std::env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("android") {
            println!("cargo:rustc-link-lib=pthread");
        }
    }
}
