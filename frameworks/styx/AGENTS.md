# Contributor guide

Orientation for anyone — human or AI — working on Styx. Read it before making
changes.

## 1. What this is

Styx is a source reimplementation of Apple's Combine that vends a **single
module named `Combine`**, so code written against the system framework builds and
runs where there is no system Combine: legacy iOS (down to iOS 6.1.3, armv7),
Linux and WASI. It is the reactive layer under [Eidolon]'s SwiftUI on the
[Charon] toolchain, consumed there as the `charon@styx` package.

### The one design decision

Apple ships Combine as one module. This fork's upstream split it into a core
module plus separate Dispatch and Foundation modules, and hid every
Foundation/Dispatch extension behind an `.ocombine` disambiguation namespace so
it could sit beside a real Combine on newer OSes. **Styx targets platforms with
no system Combine, so it folds the three into one `Combine` module and exposes
the plain API** (`Timer.publish`, `NotificationCenter.publisher`, `DispatchQueue`
/ `RunLoop` / `OperationQueue` as `Scheduler`, `Timer.TimerPublisher`). The
merge is mechanical: Dispatch lives under `Sources/Combine/Schedulers/`, the
Foundation integration under `Sources/Combine/Foundation/`, intra-module
`import`s and the `.ocombine`-only guards are gone, and the module qualifier is
`Combine.` throughout.

Consequences to respect:

- **`@Published` must not change a property's storage/layout**, and
  `objectWillChange` must fire **synchronously in `willSet`, before the write** —
  downstream (Eidolon) relies on both. Don't "optimise" the `Published` storage.
- **On Apple hosts the system `Combine` shadows this module.** SwiftPM builds and
  the test suite are for the no-Combine platforms (Linux/WASI) or the legacy-iOS
  target via Charon. `swift build`/`swift test` on macOS will pick Apple's
  Combine, not this one.
- **Availability checking stays on.** iOS 7-only calls (the `CFRunLoopTimer`
  tolerance in `Foundation/Portability.swift`) sit behind `#available`. Never
  paper over the check with `-disable-availability-checking`.

## 2. Layout

| Path | Holds |
| --- | --- |
| `Sources/Combine/` | the module — core at the top, `Schedulers/`, `Foundation/` |
| `Sources/CombineHelpers/` | the C++ helper the module links (locking primitives) |
| `Tests/` | the regression suite (runs where no system Combine shadows the module) |
| `utils/` | `recursively_gyb.sh` (`make gyb`): expands each `Sources/**/*.swift.gyb` template into the `GENERATED-*` source beside it with charon's gyb (`charon/modules/gyb`, run by xmake) |
| `Package.swift` | the SwiftPM manifest |

## 3. How to build, and how to check

**SwiftPM** (Linux/WASI, or any host without a system Combine): `swift build`.

**Legacy iOS (armv7)**: through Charon, `add_requires("charon@styx")`. That
recipe compiles the module against `charon@swift-runtime` with the runtime's
compiler and flags, and adds the runtime's `DispatchTime.distance(to:)`
supplement its older Dispatch overlay lacks.

## 4. Conventions

- **No personal data** in tracked files: no device addresses, hostnames,
  credentials, or absolute `/Users/<name>/…` paths. Use `$HOME`, placeholders,
  and a gitignored `device.env`.
- **Commits:** plain imperative subject, no type prefixes. Keep the
  writing agent's own `Co-Authored-By:` trailer — the work is openly AI-built.
- **Build artifacts are never committed.**

## 5. Traps

This section is not yet filled.

## 6. Devices, credentials, external systems

### Upstream

The `upstream` remote points at the project this started from, **fetch only**
(push is disabled). The full common history is intact; fetch periodically and
cherry-pick upstream fixes onto our tree. Do not re-add public product branding
beyond what the MIT license requires (the copyright notice in `LICENSE`).

---

## Workspace context

This repository is part of `$HOME/Git/projects/ios/`. The workspace contract
that applies to all projects here lives in `$HOME/Git/projects/ios/AGENTS.md`
(§2–§6); read it for rules on the agent work area (`.agent-work/`), git
worktrees (`.agent-work/worktrees/`), delegation, safety, and shared skills.

Workspace-wide procedures are skills in `$HOME/Git/projects/ios/.agents/skills/`: `device-session` (claim, run, install, launch, tap on a real device), `canon-install`, `patch-merge`, `worktree-sweep`, `session-handoff`, `band-launch`, `band-supervise`. A session started inside this repository does not list them — read `<name>/SKILL.md` there.

[Charon]: https://github.com/kern0x1b/charon
[Eidolon]: https://github.com/kern0x1b/eidolon
