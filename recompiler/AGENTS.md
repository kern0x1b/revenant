# The recompiler — contributor guide

The recompiler is a static binary recompiler: it takes a compiled 64-bit (arm64) iOS application and
turns it into a 32-bit (armv7) binary that runs unmodified on iOS 6, by lifting arm64 machine
code to LLVM IR (via Rellume), rewriting Objective-C metadata and data segments for the 32-bit
runtime, and re-emitting armv7 against a small support runtime plus generated ABI bridges. See
`README.md` for the pipeline overview and `CHANGELOG.md` for history. This file is the
contributor guide; revenant's own `AGENTS.md` (one level up) and the workspace contract it points at
apply too.

## Layout

| Path | What it is |
| --- | --- |
| `xmake.lua` | The member's part of the revenant xmake project, included from the top `xmake.lua` for macOS: targets `xlate` and `xlgen`, the corpus and perf targets, and the dependencies. |
| `xlate/` | The lifter: arm64 → LLVM IR, jump-table recovery, Objective-C metadata/data-bind rewriting, emits `lifted.bc`. Target `xlate`. |
| `xlate/` (`xlgen`) | Generates guest↔host ABI bridges (calling convention, `va_list`, blocks, Objective-C message dispatch, data-symbol shims) from SDK headers. Target `xlgen`. |
| `runtime/` | The armv7 support runtime: message routing, block bridging, weak references, ivar-layout reconciliation, Objective-C compatibility shims. Compiled per translation, because it includes the state header xlate writes for each app. |
| `scripts/translate.lua` | End-to-end pipeline: arm64 executable → armv7 iOS 6 executable. |
| `scripts/ipa.lua` | The same for a whole `.ipa`: its executable and embedded frameworks become one armv7 iOS 6 `.ipa`. |
| `scripts/` (others) | `env.lua` (tools and paths from the xmake configuration), `macho.lua` (the Mach-O edits the pipeline makes), `corpus.lua` (shared by the corpus checks), `imports.lua`, `absent_on_target.lua`. |
| `corpus/` | Small self-contained test programs and apps — the translator's own regression suite. `docs/corpus.md` says what each proves. |
| `perf/` | On-device translated-vs-native benchmark. |
| `targets/` | Untracked (`.gitignore`: `targets/*`, only `targets/*-includes.h` is kept): one directory per real-world app, living only on this disk. Everything under it — `*-out*`, `*-arm64`, `*.app`, `*.ipa`, `*.log`, `uistack3-official` — is **generated or investigative material**: never read it as source, never grep it wholesale, never move it. |

Rellume, farmdec and BlocksRuntime are packages of `third_party/`, pinned by commit with
our changes as patches. Rellume is built for AArch64 only, the one architecture xlate lifts.

## Building

From the revenant root. Every tool comes from a package: LLVM 23 is Revenant's `llvm` with its
`libraries` config (libLLVM, libclang-cpp, their headers, llvm-config, clang and the llvm tools
the pipeline runs), and the iOS SDK, `ld64` and `ldid` are Revenant's packages too. The first
configure builds that LLVM from source, which took 40 to 75 minutes on this machine under load.

```sh
./xmakew f -y
./xmakew build xlate xlgen
./xmakew l recompiler/scripts/translate.lua path/to/app-arm64 includes.h out/
./xmakew l recompiler/scripts/ipa.lua App.ipa includes.h out/App.ipa
```

## Checks

- `./xmakew test 'recompiler_corpus/*'` runs the host part of every corpus check.
- `./xmakew build recompiler_cxxinit recompiler_refrepro recompiler_devtime` builds the corpus apps
  and the benchmark.
- `./xmakew l recompiler/corpus/<name>/check.lua <out>` runs a check whole, including its device
  part where it has one (weakimport, classpair, swiftconformance).
- `./xmakew l tools/check.lua recompiler` runs the configuration, the build and the host checks
  together.

Run them before and after a translator change.

## Conventions

- Keep translator changes **universal**: a fix must work for any input binary, not be
  special-cased to one app. App-specific behavior belongs in `targets/<app>/`, not in
  `xlate/`/`runtime/`.
- Missing target-OS APIs are **reported, not stubbed** by the translator — that belongs to the
  separate backports effort (`revenant`), not here. The one exception is when a target genuinely
  needs a backport that doesn't exist yet: route that request to the relevant backports band,
  don't improvise a stub in `runtime/`.
- Scripts are Lua run by `./xmakew l`; no shell or Python scripts. No comments in code, scripts or
  recipes: the why goes in the commit message, and knowledge a reader needs goes in `docs/`.
- Forward-only, same as the rest of the workspace: no destructive git operations without
  explicit sign-off, nothing that another session produced gets reverted or discarded.
- **Git holds source only.** Run output — device crash logs and syslogs, screenshots, message
  traces, script output (`report.txt`, `imports.txt`, `results.txt`), generated tables such as
  `*.absent.tsv`, survey dumps — goes to `$HOME/.revenant/cache/<task>/`, never into a commit or
  the revenant tree, and is deleted when the task ends. Record the finding in a commit message, a
  facts line or a doc. Before committing, read `git status` and `git diff --cached --stat`: a new
  file that a script or a device wrote is not source.
- Device identifiers (UDIDs, crash-log `CrashReporter Key`s) and screenshots do not go even into
  scratch notes — that's a standing privacy rule, not a git rule. Delete a screenshot once
  it has verified the state it was taken for.

## Translation input

The translator takes a compiled arm64 Mach-O, never source. For a real-world app under `targets/`
that means the decrypted executable and frameworks of its released `.ipa`, never objects built
from an edited copy of its source: the owner forbids editing Telegram's source, in the tree or as
copies (`coordination/FLEET.md`, "2026-09-24 — правило владельца для линии Telegram"). `corpus/`
and `perf/` build their own arm64 input from their own source.

UIStack built from Telegram's source belongs to the Telegram-from-source line, not to this
repository.

## The revenant addon

- **Check a toolchain version only in a `XMAKE_GLOBALDIR` of your own**, the way
  `tests/addon/store_test.lua` does. Clone the toolchain at the version under check, delete that clone's
  `*.lock`, install it into your own `XMAKE_GLOBALDIR`, compare the shared
  `~/.xmake/addons/addons.conf` `active` before and after, then remove that store. Reason: on
  xmake 3.1.1 every addon install becomes the machine's `active` version
  (`coordination/crutches.md`, the xmake addon lock entry).
- **The payload under `~/.xmake/addons` is never edited by hand**: no copying files into it, no
  `xmake addon --remove`. A stale payload is diagnosed read-only
  (the skill `recompiler-addon-refresh`) and handed to the coordinator.

## Devices and the emulator

iPhone 4S and iPad 2, both iOS 6.1.3. The procedure for any device session — claim, run,
install, launch, tap, respring, cleanup — is the workspace skill `device-session`
(`$HOME/Git/projects/ios/.agents/skills/device-session/SKILL.md`); the fleet's device traps are
in `toolchain/COORDINATION.md` §5. The emulator is reached through the skill `emulate-port`.
Specific to this repository: the 4S carries the owner's real Telegram account — never read, log,
or forward chat or contact content, never tap a chat-list row, and don't leave Telegram open
after a check.
