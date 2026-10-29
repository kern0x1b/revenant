# AIR from Apple's Metal compiler: the metal-toolchain package

Status: blocked. The package is not written yet, because it needs Xcode installed on this Mac, which the owner has been
asked to do. Nothing here is built or published.

## Why

Compute lowering (`metal-on-ios6.md` section 3, items 8 and 9) and the MPS checks both need AIR made by Apple's Metal
compiler. This Mac has no such compiler: the Command Line Tools have none, `xcodebuild` is their stub, and
`MTLCompiler.framework` in the iPhoneOS SDK is a link stub. Since Xcode 26 the Metal compiler is a separately
downloadable component, so it has to come from Apple's component service.

## The package

- **Name:** `metal-toolchain`, a revenant toolchain package kept in the shared store, as `iphoneos-sdk` is.
- **Source:** Apple's own component, fetched by the official `xcodebuild -downloadComponent metalToolchain`, with
  `-exportPath` to write the bundle to a file. Nothing is downloaded from a host that is not Apple's, and no host is
  guessed. The package takes `metal` and `metallib` from the exported bundle.
- **Pin:** the toolchain version, which `xcrun metal --version` reports, and the sha256 of the `metal` and `metallib`
  binaries. A different toolchain is a different package version.
- **Publishes nothing.** Local tools use the installed package. No CI job runs and no release is made. (An earlier
  design made the package a CI prebuilt. That design is replaced, because it would publish Telegram's shaders.)

## What it compiles

- **Input:** Telegram's `.metal` files from the read-only reference checkout `~/Git/reference/Telegram-iOS-release-13.0.0`.
  Of the 30 `.metal` files there, the two under `build-system/bazel-rules/rules_apple/test/` are test samples and are not
  counted. The remaining 28 are `MetalUsage.md`'s set, provided the checkout matches the revision that the usage scan
  used. One of the 28 is ffmpeg's `vf_yadif_videotoolbox.metal`, which is not Telegram's shader; the coverage count
  needs to decide whether to keep it.
- **Command:** `xcrun -sdk iphoneos metal -c -target air64-apple-ios8.0 <flags> file.metal -o file.air` for each file,
  then `xcrun -sdk iphoneos metallib` for the set. The target is iOS 8.0 or later, as the Metal framework requires.
- **Flags:** must be the ones Telegram's own Bazel Metal rules pass, read from the reference checkout, not guessed.
  That reading is the next step after Xcode is installed.
- **Output:** the `.air` files and the `.metallib` go to the scratch folder, keyed by the sha256 of each input, and are
  never published.

## Before it can run

1. Xcode installed on this Mac (owner's action). Then `xcodebuild -downloadComponent metalToolchain -exportPath <folder>`
   and the package records the exported toolchain's version and hashes.
2. The Telegram flags read from the reference checkout's Bazel Metal rules.

The macOS metallibs already in `/Applications/Telegram.app` are macOS AIR from Telegram's own build. They can teach the
kernel metadata layout now, but they are not iOS AIR, so they are not the iOS oracle.
