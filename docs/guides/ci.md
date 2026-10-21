# Continuous checks

`.github/workflows/check.yml` runs on every push to any branch, and on demand from the Actions tab or with
`gh workflow run check.yml --ref <branch>`. Its two jobs run in parallel, both on `macos-26`:

- `checks` runs `./xmakew test -P .`: every test a host with the prebuilt packages can run, in parallel. That is the
  repository's layout and comment checks (`repository/*`), the toolchain's suites (`toolchain_light/*` and
  `toolchain_packages/*`), the emulator's and the recompiler's host tests. It sets `REVENANT_PREBUILT=kern0x1b/revenant`
  and `REVENANT_PREBUILT_ONLY=1`, so LLVM and Swift come from their releases and a missing release is an error, not a
  source build. The tests that need a device, an emulator image or firmware are not declared on CI; see
  [the tests reference](../reference/toolchain/tests.md).
- `backports` selects the newest Xcode and sets `REVENANT_PREBUILT=kern0x1b/revenant`, so LLVM and Swift come from
  their releases and are never built in the job. It configures and builds the Backports component
  (`./xmakew f -P . -p iphoneos -a armv7 --component=Backports`, then `./xmakew build -P .`) and uploads
  `build/iphoneos/armv7/release/lib*.dylib` as the artifact `backports-libraries`. A branch without the `component`
  option skips both steps, and the job summary says so.

The checks run on macOS, not Linux: the suites compile with the Mac's clang and the emulator is a macOS program. Every
test in the default run must pass, so the `checks` job is red when one of them fails, and no test is skipped in CI
by a list of names.

Four caches make a warm run quick:

- the pinned xmake binary, keyed by `xmakew` and `third_party/xmake`;
- the package store `~/.revenant/cache/xmake-global`, which holds the iPhoneOS SDK and the linker. It is keyed by the
  output of `./xmakew l tools/keys.lua iphoneos-sdk ld64`, so only a change to those two packages makes a new key. It
  is restored by exact key and saved once, after the configure has succeeded, so a store is never saved half-made;
- the generated skeleton `build/generated/backports`, keyed by `frameworks/Backports/**` and saved on the same condition;
- the objects `build/.objs`, their depfiles `build/.deps` and the libraries `build/iphoneos`, keyed by the store key and
  by the hashes of `frameworks/Backports/**`, `toolchain/**`, `packages/**`, `addons/**`, `third_party/**`, `xmake.lua`
  and `xmakew`, saved once the
  build has succeeded.

xmake recompiles a source whose mtime is newer than its depfile, and a restored cache has older depfiles than a fresh
checkout has sources. So the job first gives every tracked file one fixed mtime, and the skeleton writer rewrites a
generated file only when its text changed, so a restored skeleton keeps the mtime its objects were built against.

A warm run that restores its store writes nothing back. The backports job installs no LLVM from Homebrew: the
toolchain's `llvm` (its clang, which monocypher builds with) and `ld64` come from their prebuilt releases, and
`REVENANT_PREBUILT_ONLY=1` makes a missing release an error instead of a source build.

## Fetching a branch's artifacts

The latest run of a branch holds its artifact even when its `checks` job is red:

```
run=$(gh run list --workflow check.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$run" --name backports-libraries --dir "$HOME/.revenant/cache/ci/$run"
```

The download is scratch: delete it when the task ends. An artifact exists only for a run whose `backports` job built
the component, so a branch without the option has none.
