# Continuous checks

`.github/workflows/check.yml` runs on every push to any branch, and on demand from the Actions tab or with
`gh workflow run check.yml --ref <branch>`. Its three jobs run in parallel, all on `macos-26`. Each selects Xcode 26.6
and sets the prebuilt variables through the composite action `.github/actions/revenant-setup`; a composite action cannot
choose a runner, so each job keeps its own `runs-on`.

- `checks` runs `./xmakew test -P .`: every test a host with the prebuilt packages can run, in parallel. That is the
  repository's layout and comment checks (`repository/*`), the toolchain's suites (`toolchain_light/*` and
  `toolchain_packages/*`), the emulator's and the recompiler's host tests. It sets `REVENANT_PREBUILT=kern0x1b/revenant`
  and `REVENANT_PREBUILT_ONLY=llvm,swift,ld64`, so LLVM, Swift and ld64 come from their releases and a missing release is an error, not a
  source build. It configures with `--emulator_vulkan=n`: the Vulkan renderer's SwiftShader is built from source, which
  takes most of the job, and the tests do not use it. The option stays on for the emulator's own builds. The tests that need a device, an emulator image or firmware are not declared on CI; see
  [the tests reference](../reference/toolchain/tests.md).
- `backports` sets `REVENANT_PREBUILT_ONLY=llvm,swift,ld64`, so LLVM and Swift come from their releases and are never
  built in the job. It configures and builds the Backports component
  (`./xmakew f -P . -p iphoneos -a armv7 --component=Backports`, then `./xmakew build -P .`) and uploads
  `build/iphoneos/armv7/release/lib*.dylib` as the artifact `backports-libraries`.
- `swift` configures the Swift component, builds the Swift targets (AppIntents, ActivityKit, TipKit, swiftSpatial,
  swiftCloudKit, swiftWeatherKit) and installs the Swift packages through their wrappers. It names `swift-runtime` and
  `libcxx` in `REVENANT_PREBUILT_ONLY` as well, so a missing release of either is an error.

The checks run on macOS, not Linux: the suites compile with the Mac's clang and the emulator is a macOS program. Every
test in the default run must pass, so the `checks` job is red when one of them fails, and no test is skipped in CI
by a list of names.

Four caches make a warm run quick:

- the pinned xmake binary, keyed by `xmakew` and `packages/x/xmake`;
- the package store `~/.revenant/cache/xmake-global`. The backports job keys it by the output of
  `./xmakew l tools/keys.lua iphoneos-sdk ld64`, so only a change to those two packages makes a new key. The checks job
  keys its own store by the files that decide what it installs: the xmake recipes of the packages, the third-party
  packages the default tests build, `toolchain/modules/prebuilt.lua`, and the component files that declare requirements.
  Each store is restored by exact key and saved once, after the configure has succeeded, so a store is never saved
  half-made;
- the generated skeleton `build/generated/backports`, keyed by `frameworks/Backports/**` and saved on the same condition;
- the objects `build/.objs`, their depfiles `build/.deps` and the libraries `build/iphoneos`, keyed by the store key and
  by the hashes of `frameworks/Backports/**`, `toolchain/**`, `packages/**`, `addons/**`, `xmake.lua`
  and `xmakew`, saved once the
  build has succeeded.

xmake recompiles a source whose mtime is newer than its depfile, and a restored cache has older depfiles than a fresh
checkout has sources. So the job first gives every tracked file one fixed mtime, and the skeleton writer rewrites a
generated file only when its text changed, so a restored skeleton keeps the mtime its objects were built against. The `checks` job takes no fixed mtime, because it
restores only the package store, which holds no `build/` objects: nothing it restores is compared with a source's mtime.

A warm run that restores its store writes nothing back. The backports job installs no LLVM from Homebrew: the
toolchain's `llvm` (its clang, which monocypher builds with) and `ld64` come from their prebuilt releases, and
`REVENANT_PREBUILT_ONLY` names the packages whose missing release is an error instead of a source build; `1` names all of them.

## Fetching a branch's artifacts

The latest run of a branch holds its artifact even when its `checks` job is red:

```
run=$(gh run list --workflow check.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$run" --name backports-libraries --dir "$HOME/.revenant/cache/ci/$run"
```

The download is scratch: delete it when the task ends. An artifact exists only for a run whose `backports` job built
the component, so a branch without the option has none.
