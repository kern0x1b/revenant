# Build a Rust crate for armv7 on iOS 6

A port links a Rust crate through the `rust` rule. The rule builds the crate as a static library for the armv7 target of iOS 6.0, which is the iPhone 4S's Apple A5 on iOS 6.1.3, with the nightly pinned by `revenant@rust`. The reasons for the target, the nightly and the warnings are in [Rust on iOS 6](../../explanation/toolchain/rust.md).

## Requirements

The port requires the package and names the armv7 iOS 6.0 target as for any port:

    set_config("apple_minimum", "6.0")
    includes("@addon/revenant/apple-ios")
    set_defaultplat("iphoneos")
    set_defaultarchs("iphoneos|armv7")
    add_requires("revenant@rust nightly-2026-10-22", {alias = "rust"})

The first install downloads rustup and the nightly with its `rust-src` component, which `-Zbuild-std` needs.

## The crate

The rule builds the crate's library target as a staticlib, so the crate's `Cargo.toml` and its committed `Cargo.lock` sit in a folder of the port. The build is `--locked`, so a crate without its lock does not build. The rule builds with the `[profile.release]` of the manifest except LTO, which it turns off, and it passes `-Cembed-bitcode=no`: an archive holds machine code, since the linker of this toolchain rejects some bitcode members.

The target names the folder, and the program that links it names the target:

    target("wallet")
        add_rules("@addon/revenant/rust")
        set_values("rust.crate", "rust/wallet")
        set_values("rust.library", "wallet_engine")

    target("Example")
        add_rules("@addon/revenant/app")
        add_deps("wallet")
        add_packages("apple-compat")

`rust.library` is the crate's `[lib]` name, which names the archive `lib<name>.a`; by default it is the target's name with `-` turned into `_`. The target publishes that name and its folder as public link settings, so `add_deps("wallet")` links the archive with no further value.

Three values shape the build, and each follows what Telegram's own build passes to rules_rust:

- `rust.package` names the workspace member to build, with `-p`, when the crate folder is a workspace.
- `rust.features` names the exact feature set; the default features are off, as they are in rules_rust.
- `rust.rustflags` adds rustc flags, such as `-Copt-level=3` and `-Cpanic=abort`.

A crate that calls the C library through the `cc` crate gets the apple-ios toolchain's clang, its SDK and its deployment target through `CC_armv7_apple_ios6`, `CFLAGS_armv7_apple_ios6` and `SDKROOT`. A crate that calls a system function that iOS 6 lacks gets the shim from the program that links it: `add_packages("apple-compat")`, as above. The import check names the shim when one is missing.

## Build

    xmake

The first build compiles `core`, `alloc`, `std` and `panic_abort` for the target, which takes minutes. The target tracks every `.rs` and `.toml` file under its crate folder, and `Cargo.lock`, by their hashes in `sources.toml` beside its objects; an edit to any of them runs cargo again, and cargo rebuilds only what changed. The jobs count is `XMAKE_MAX_JOBS`, and it defaults to the machine's cores.

The linked binary is checked as any other: every non-weak import must exist on the device's iOS 6.0 release, and a missing one stops the build and names the shim that provides it.

## What the build prints

Two messages are expected and are not suppressed:

- cargo prints `deployment target in IPHONEOS_DEPLOYMENT_TARGET was set to 6.0, but the minimum supported by rustc is 10.0`, once per crate. rustc uses 10.0 for the code it generates.
- the linker prints `object file ... was built for newer iOS version (10.0) than being linked (6.0)` for each member of the archive. The binary itself records 6.0. The linker prints it twice per member.

The explanation gives the measurement behind both, and why the linker's message is not hidden.

## Limits on this release

The shims answer what iOS 6 can do safely. `std::fs::remove_dir_all` recurses through descriptors and works: each descriptor call pins its folder for that call, so a folder renamed during the walk is still the one emptied. `std::fs::read_dir`, `copy`, `rename` and `hard_link` work through the paths they are given. A call that needs two folders named by descriptors in one call answers `ENOTSUP`, and so do `RENAME_EXCL` and `fclonefileat`; std takes those answers as its cue to fall back. The `std::os::darwin::fs` directories answer the sandbox's user domain only. The reasons are in [Rust on iOS 6](../../explanation/toolchain/rust.md).

## Changing the nightly

The nightly is the package's `channel` config and its version. A new nightly needs a new `add_versions` key with the rustup-init checksum that the recipe pins, and the spec must still load under it: `toolchain_light/rust_test` and the package's own test run `rustc --print cfg` on the spec. A new nightly is a new version of `revenant@rust`, so a port that requires the old one keeps it.
