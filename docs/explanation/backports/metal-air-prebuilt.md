# AIR from Metal's compiler, as a prebuilt

Status: design only. Nothing here is built or dispatched. The recipe and the workflow input follow once the two owner
decisions in the last section are made.

## Why

Compute lowering (`metal-on-ios6.md` section 3, items 8 and 9) and the MPS checks both need AIR made by Apple's Metal
compiler. This Mac has no such compiler: only the Command Line Tools are installed, and `MTLCompiler.framework` in the
iPhoneOS SDK is a link stub with no compiler in it. So AIR has to come from a Mac that has Xcode, and the only machine
the project has that way is a CI runner. The result is a prebuilt, as LLVM and Swift already are
(`docs/guides/prebuilt.md`).

## The package

- **Name:** `metal-air`. A package in the prebuilt scheme, wired with `prebuilt.fetch`, `prebuilt.install` and
  `prebuilt.pack`, as the guide describes for the other recipes.
- **Input:** a set of `.metal` files, the compile flags, and a pinned Xcode.
- **Output:** `metal-air-<key>-macosx-arm64.tar.xz` with its `.sha256`. The archive holds one `<name>.metallib`, the
  per-file `.air` files, and `manifest.json`.
- **Key:** the prebuilt key of the package's configs. The `sources` config is the sorted sha256 list of the `.metal`
  files, so a changed shader is a new key. The `flags` config is the exact compile line, including the target triple
  and the language standard. The `xcode` config is the build number from `xcodebuild -version`, and the `sdk` config
  is the SDK version. An unchanged set is never compiled twice.

## The build, on CI only

1. Select the pinned Xcode by path, then fail unless `xcodebuild -version` prints the pinned build number.
2. For each file: `xcrun -sdk <sdk> metal -c <flags> file.metal -o file.air`.
3. `xcrun -sdk <sdk> metallib file.air ... -o <name>.metallib`.
4. Write `manifest.json`: `xcrun metal --version`, the Xcode build number, the SDK version, the flags, and the sha256
   of every output.
5. Compile the set a second time in the same job and compare. A mismatch fails the job. Whether Apple's output is
   byte-identical across runs is not known; this check is how the project will learn it.

The flags must match the ones that made Telegram's metallib, since the oracle is macOS `air64` [air2es]. They have to be
read from Telegram's Bazel Metal rules, not guessed here.

## On a machine

Local tools download the archive and check its sha256. No `.metal` file is needed and no compiler runs. With
`REVENANT_PREBUILT_ONLY=metal-air`, a missing release is an error, so a local build can never fall back to compiling.
air2es and the host harness read the `.metallib` from the unpacked folder.

## Owner decisions before anything is dispatched

1. **Where the sources come from.** The 28 `.metal` files belong to Telegram, in the `telegram-build` repository, not in
   this one. CI would need a checkout of that repository and a credential for it. That is the owner's call.
2. **Where the release goes.** `prebuilt.yml` publishes with `gh release create --prerelease` into
   `kern0x1b/revenant`, which is a public repository. A public release of shaders compiled from Telegram's source would
   republish Telegram's code in another form. The owner decides whether it may be published at all, and if not, where
   the archive goes instead (a private release, or an artifact that stays in the owner's account).

Until both are answered, the workflow stays as it is, `metal-air` is not added to its `package` list, and no
recipe is wired.
