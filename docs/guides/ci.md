# Continuous checks

`.github/workflows/check.yml` runs on every push to any branch, and on demand from the Actions tab or with
`gh workflow run check.yml --ref <branch>`. Its two jobs run in parallel, both on `macos-26`:

- `checks` runs the comment check (`./xmakew l tools/comments.lua check`), the layout check and the toolchain check
  (`./xmakew l tools/check.lua toolchain`, the light guard). The layout check reports its count of breaks in the
  step summary and does not fail the job yet. The toolchain check fails while the light guard fails, so the job is
  red on any branch where that is so.
- `backports` selects the newest Xcode and sets `REVENANT_PREBUILT=kern0x1b/revenant`, so LLVM and Swift come from
  their releases and are never built in the job. It configures and builds the Backports component
  (`./xmakew f -P . -p iphoneos -a armv7 --component=Backports`, then `./xmakew build -P .`) and uploads
  `build/iphoneos/armv7/release/lib*.dylib` as the artifact `backports-libraries`. A branch without the `component`
  option skips both steps, and the job summary says so.

The checks run on macOS, not Linux: on Linux the light guard stops early at `registry_test`, which finds gaps there
that it does not find on macOS. The light guard skips `doc_test` (`LIGHT_SKIP`), which tests the old generator and is
deleted with the registry; the workflow prints a notice saying so. Every other suite must pass, so the `checks` job
is red when one of them fails.

Two caches make a warm run quick: the pinned xmake binary, keyed by `xmakew` and `third_party/xmake`, and the
package store `~/.revenant/cache/xmake-global`, keyed by the output of `./xmakew l tools/keys.lua`. Each cache is
saved even when its job fails, so a red run still leaves the next one warm.

## Fetching a branch's artifacts

The latest run of a branch holds its artifact even when its `checks` job is red:

```
run=$(gh run list --workflow check.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$run" --name backports-libraries --dir "$HOME/.revenant/cache/ci/$run"
```

The download is scratch: delete it when the task ends. An artifact exists only for a run whose `backports` job built
the component, so a branch without the option has none.
