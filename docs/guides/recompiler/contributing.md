# Contributor guide: the recompiler

The recompiler takes a compiled 64-bit (arm64) iOS application and turns it into a 32-bit (armv7) binary that runs
unmodified on iOS 6, by lifting arm64 machine code to LLVM IR, rewriting the Objective-C metadata and data segments
for the 32-bit runtime, and re-emitting armv7 against a small support runtime plus generated ABI bridges. The
repository's root `AGENTS.md` applies.

[How it works](../../explanation/recompiler/how-it-works.md) describes the pipeline, and
[build and translate](build-and-translate.md) the commands.

## Layout

| Path | What it is |
| --- | --- |
| `xmake.lua` | The member's part of the revenant xmake project, included from the top `xmake.lua`: the targets `xlate` and `xlgen`, the corpus and perf targets, and the dependencies. |
| `src/xlate/` | The lifter: arm64 to LLVM IR, jump-table recovery, Objective-C metadata and data-bind rewriting, and the `lifted.bc` output. Target `xlate`. Also `xlgen`, which generates the guest-to-host ABI bridges from the SDK headers. Target `xlgen`. |
| `src/runtime/` | The armv7 support runtime: message routing, block bridging, weak references, ivar-layout reconciliation, Objective-C compatibility shims. Compiled per translation, because it includes the state header xlate writes for each app. |
| `tools/` | `translate.lua` and `ipa.lua`, the pipeline; `env.lua` (tools and paths from the xmake configuration), `macho.lua` (the Mach-O edits), `corpus.lua` (shared by the corpus checks), `imports.lua` and `absent_on_target.lua`. |
| `tests/` | Small self-contained test programs and apps: the translator's regression suite. [The corpus](../../reference/recompiler/corpus.md) says what each check proves. |
| `tests/perf/` | The on-device translated-versus-native benchmark. |
| `targets/` | Not a folder of the repository: its two `*-includes.h` lists are in `include/`. A real-world app's folder, `targets/<app>/`, is untracked and lives only on the disk that builds it. Everything under it, `*-out*`, `*-arm64`, `*.app`, `*.ipa`, `*.log`, is generated or investigative material. Never read it as source, never grep it wholesale, never move it. |

Rellume, farmdec and BlocksRuntime are packages of `third_party/`, pinned by commit with our changes as patches.

## Conventions

- Keep translator changes **universal**: a fix must work for any input binary, not be special-cased to one app.
  App-specific behaviour belongs in `targets/<app>/`, not in `src/xlate/` or `src/runtime/`.
- Missing target-OS APIs are **reported, not stubbed** by the translator. They belong to the backports. When a target
  needs a backport that does not exist yet, route the request to the backports and do not improvise a stub in
  `src/runtime/`.
- Scripts are Lua run by `./xmakew l`; no shell or Python scripts. No comments in code, scripts or recipes: the why
  goes in the commit message, and what a reader needs goes in `docs/`.
- Git is forward only, as the root `AGENTS.md` says.
- **Git holds source only.** Run output (device crash logs and syslogs, screenshots, message traces, script output
  such as `report.txt`, `imports.txt` or `results.txt`, generated tables such as `*.absent.tsv`, survey dumps) goes to
  `$HOME/.revenant/cache/<task>/`, never into a commit or the revenant tree, and is deleted when the task ends. Record
  the finding in a commit message, a facts line or a doc. Before committing, read `git status` and
  `git diff --cached --stat`: a new file that a script or a device wrote is not source.
- Device identifiers (UDIDs, crash-log keys) and screenshots do not go even into scratch notes. Delete a screenshot
  once it has verified the state it was taken for.

## The revenant addon

- Check a toolchain version only in an `XMAKE_GLOBALDIR` of your own, the way `toolchain/tests/addon/store_test.lua`
  does. On xmake 3.1.1 every addon install becomes the machine's `active` version, so an install into the shared store
  changes it for every project.
- The payload under `~/.xmake/addons` is never edited by hand: no copying files into it, no `xmake addon --remove`.

## Devices and the emulator

The test devices are an iPhone 4S and an iPad 2, both on iOS 6.1.3. A device session follows the skill
`device-session` (`.agents/skills/device-session/SKILL.md`). The emulator is reached through the skill `emulator-session`
(`.agents/skills/emulator-session/SKILL.md`).

A test device may carry a personal account. Never read, log or forward its content, and close any app a check opened
on it.
