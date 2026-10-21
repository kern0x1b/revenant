# Clean-machine tests

The skills are proven only by an agent that followed them from an empty directory. Each scenario
under `agent-skills/tests/data/scenarios/<id>/` is a request, the user's answers to the interview, and the release, device,
architecture and language the run must end up with (`scenario.conf`). No scenario carries code, and
no app they describe exists anywhere in this repository.

| id | App | iOS | Device | Language |
| --- | --- | --- | --- | --- |
| `list` | shopping list with persistence | 5.1.1 | iPhone 3GS (`iPhone2,1`) | Objective-C |
| `timer` | countdown timer | 6.0 | iPhone 4 (`iPhone3,1`) | Swift |
| `net` | network request, iPad split layout | 6.1.3 | iPad 2 (`iPad2,1`) | Objective-C |
| `gestures` | canvas driven by gestures | 6.1.3 | iPhone 4S (`iPhone4,1`) | Swift |
| `swiftui` | habit tracker | 6.1.6 | iPod touch 4 (`iPod4,1`) | Swift, SwiftUI |

## Run

From the revenant checkout:

```
./xmakew l agent-skills/tests/run.lua [--runtime claude] [--hours N] list timer …   # or: all
```

Run output goes under `$HOME/.revenant/cache/<task>/agent-skills/` (`toolchain/modules/workspace.lua`
names the task). For each scenario `run.lua`:

1. makes a scratch directory `scratch.<random>` there, outside any repository, and in it a fresh
   `HOME`;
2. clones revenant at `HEAD` (the tree must be committed) and installs the plugin into that `HOME`
   with the runtime's own commands: for Claude Code `claude plugin marketplace add <clone>` and
   `claude plugin install agent-skills@revenant`;
3. copies the scenario's `answers.md` into an empty project directory and runs the agent there,
   headless, on `request.md`;
4. runs `check.lua` and copies the evidence (transcript, check, project without build products,
   `.deb`s) to `<run>/<id>/` next to the scratch directory.

Shared on purpose, not isolated: the xmake package store (`XMAKE_GLOBALDIR` is the real home, so
nothing is rebuilt into a private store) and Revenant's firmware, caches and emulator images
(`REVENANT_HOME`). A guard in front of `xmake` refuses `--force` and `xmake emulate clean`.

`run.lua` refuses to start unless `REVENANT_AGENT_SKILLS_ISOLATION_APPROVED=1` is set (the isolation is
approved; the variable keeps an accidental run from starting it).

Login. On macOS the agent's login lives in the login keychain, and a fresh `HOME` is not logged in
(measured: `Not logged in`). `run.lua` therefore copies only the Claude login from the keychain into
the scenario's `HOME` as `.claude/.credentials.json`, mode `600`. That `HOME` is removed as soon as
the scenario ends, when the run stops on an error, and on Ctrl-C. A `kill` with TERM or HUP skips
that cleanup: xmake's Lua catches only SIGINT, so remove `home-*` in the scratch directory by hand
after one. The evidence is scanned for the exact token before the `HOME` goes, and `check.lua`
scans it again for credential files and token shapes. The file never
reaches the evidence, a log or git. Each scenario is capped to the access token's remaining
lifetime minus 15 minutes, so the copy never has to refresh the login.

## What counts

`./xmakew l agent-skills/tests/check.lua PROJECT SCENARIO PLUGIN [EVIDENCE]` prints one `ok`/`FAIL` line per check and ends with
`RUN COUNTS` only if all pass:

- the app's own sources are in the scenario's language, and `PROJECT.md` exists;
- no `SKILL.md` in the project, and no run of five significant lines shared with any file of the
  plugin (the scenarios themselves excluded);
- `xmake.lua` sets `apple_minimum` to the scenario's release;
- a built `.app` whose executable has the scenario's architecture and minimum OS;
- a `pass on <device> <release>` line from `xmake emulate` in the project's `.logs/`;
- an app `.deb` for `iphoneos-arm` carrying the bundle under `/Applications`;
- no login credentials in the copied evidence.

Until the toolchain can launch an app through SpringBoard in the emulator, the emulator line proves that
the image booted with the app installed and the checked command passed, not that the app's screen
worked. The check will be tightened when that lands.

## Validating the manifests

```
claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json --strict
```
