# Contributor guide

Orientation for anyone - human or AI assistant - working on this repository.
Read it before making changes. The deep material lives in the two long-form
documents at the root; this file is the map to them and to the tree.

## What this is

If the effort has to be rebuilt from nothing - every session gone - read
[COORDINATION.md](COORDINATION.md) first. It carries the team structure, the flow patches
travel through, the known traps, and the restart procedure. This file stays the
map of the code.

Charon builds legacy Apple platforms for [xmake](https://xmake.io) and Conan:
armv6 (iPhone OS 2.0-4.2.1), armv7 (from iPhone OS 3.0), armv7s (from iOS 6) and
arm64 (from iOS 7), driven by clang from the `llvm` package with no Xcode. A
port is an ordinary declaration in each module; Charon adds only what the build
system does not already know about these platforms:

- an **addon / driver** - the `apple-ios` toolchain, the `tweak`/`daemon`/`app`
  rules, the Mach-O checks every binary is held to where it links (Thumb
  interworking, `__PAGEZERO`, `LC_ENCRYPTION_INFO`, missing syscalls, imports
  against the device's own dyld shared cache), strip and `ldid` signing,
  reproducible Debian packages, and the device transport;
- a **package repository** - the SDK, ld64 (cctools-port), ldid, libplist, the
  C++ runtime, and the libraries ports share, each under `charon@name`.

The driver is meant to be as usable for other platforms (old macOS, current iOS,
Android) as it is here; iOS 6 is the first platform it targets, not its limit.

## Where to look

- **`README.md`** - the authoritative reference: how to write a port, the rules
  and the values each reads, the Conan driver, the package layout, packaging and
  the linker. Start here for anything task-specific.
- **`DESIGN.md`** - how the pieces fit and *why*, including the Gradle/Maven ->
  Charon mapping for anyone arriving from the JVM world.
- **Skills** (`.agents/skills/`): `backports-gate` - gating apple-backports and reading the
  verdict; `corpus-regen` - the registry export and demand data after a push; `emulate-port` -
  `xmake emulate`. The `xmake-*` skills are vendored (`VENDORED.md`).
- **Workspace-wide procedures** are skills in `$HOME/Git/projects/ios/.agents/skills/`:
  `device-session` (claim, run, install, launch, tap on a real device), `canon-install`,
  `patch-merge`, `worktree-sweep`, `session-handoff`, `band-launch`, `band-supervise`. A session
  started inside this repository does not list them - read `<name>/SKILL.md` there.

## Repository layout

| Path | Holds |
| --- | --- |
| `config/` | Conan configuration: settings, hooks, and the `charon` driver + platform facts under `config/extensions/`. |
| `recipes/` | Conan recipes - the SDK, ld64, ldid, libplist, libcxx, the imports check, and the `charon-base` / `charon-apple` bases every port extends. |
| `modules/` | build modules / ports. |
| `packages/` | package definitions. |
| `plugins/` | build plugins. |
| `rules/` | build rules. |
| `toolchains/` | toolchain definitions. |
| `addons/`, `includes/` | xmake addon and shared includes. |
| `tools/` | diagnostic/maintenance helpers (e.g. `assets-extract/`, which writes a compiled asset catalogue as loose files). |
| `tests/` | the test suites. |

## Conventions

- **No personal data in the repo.** No device addresses, hostnames, credentials,
  or absolute `/Users/<name>/...` paths in tracked files - use `$HOME`,
  placeholders, and a gitignored `device.env`.
- **Commit messages:** plain imperative subject describing the change, no type
  prefixes or scope tags. An agent's `Co-Authored-By:` trailer is optional (owner,
  2026-09-27): welcome, never a reason to send a commit back.
- **A recipe takes a dependency by platform, not by name.** `package:dep(name)` is keyed by the package's name, and a host tool
  in the graph (ldid) brings its own dependencies with it, so a target's openssl and the host's meet at one key and the later
  wins: tdlib linked a macOS libcrypto that way. Use `modules/apple/dependency.lua`'s `target_dependency(package, name)`
  wherever a dependency's folder goes to CMake or a linker, and do not put a host tool or anything with library
  dependencies into a recipe that other packages depend on: what it depends on, they depend on too.
- **Build artifacts are never committed** (`build/`, `.xmake/`, and per-package
  build trees are gitignored) and are reproducible from the recipes.
- This repository receives frequent merges through a separate flow; coordinate
  before landing wide changes.

## Traps

Each entry: wrong pattern -> right pattern -> the mechanical reason.

- **The shared `~/.xmake` store, not a private one.** Wrong: `xmake require --force`,
  `xrepo install --force`, `rm -rf ~/.xmake/packages/...`, or a private `XMAKE_GLOBALDIR` to pick
  up a changed recipe or patch. Right: just rebuild normally against the shared store. Reason:
  every package that matters here (`apple-backports`, `llvm`, `swift-runtime`, `libcxx`, `swift`)
  hashes its own sources, patches and recipe into a readonly digest config (`sources`/`recipe` -
  see `packages/a/apple-backports/xmake.lua` and `packages/s/swift-runtime/digest.lua`), so a
  changed backport, patch or recipe is already a different package with its own install path -
  no force needed, no collision with another band's build (a change that's only a comment or
  layout is deliberately excluded from the digest, by design). A private store instead
  re-resolves the whole dependency chain from network, up to rebuilding LLVM from source - never do
  that either. If a build's own output needs
  to survive the shared store regardless of any package (a crash log, failure text), redirect it
  to your own file instead of isolating anything: `xmake -y > build.log 2>&1`.

- **Device-side binaries and the toolchain.** Wrong: building a device-side binary - including a
  throwaway probe - with the host's own `cc`/`clang`. Right: build it through a `target()` using
  `@addon/charon/daemon` (or `app`/`tweak`) against this driver's `apple-ios` toolchain, same as
  any port. Reason: a Mach-O built for the wrong target crashes with `Bad system call: 12`
  (SIGSYS) before its own code runs on the device's old kernel - indistinguishable from a
  codesigning/sandbox rejection by symptom alone.

- **`NSMapTable` and non-object keys/values.** Wrong: building an `NSMapTable` with default
  options (including `strongToWeakObjectsMapTable`) when a key or value is an opaque C pointer
  bridged with `(__bridge id)` (e.g. a `JSGlobalContextRef`). Right: build it with
  `+mapTableWithKeyOptions:valueOptions:`, using `NSPointerFunctionsOpaqueMemory |
  NSPointerFunctionsOpaquePersonality` for the non-object side. Reason: default options send
  `retain`/`release` to keys and values, and `objc_retain` on a non-object crashes inside
  `NSConcreteMapTable` with no hint of the real cause.

- **Calling a block by its own pointer.** Wrong: casting a block's own pointer to a C function
  type and calling it. Right: read the `invoke` field out of the block's layout
  (`{isa, flags, reserved, invoke, ...captures}`) and call that, bridging through `void *` first
  (ARC forbids calling an Objective-C pointer as a raw function pointer). Reason: the block
  pointer's own bytes are `isa`, not code.

- **`NSInvocation` argument lifetime.** Wrong: calling `-setArgument:atIndex:` without first
  calling `-retainArguments`, when the argument's source local can go out of scope before
  `-invoke` runs. Right: call `-retainArguments` immediately after creating the invocation, before
  setting any arguments. Reason: `-setArgument:atIndex:` copies bytes, not objects, so the pointer
  dangles once its scope ends - and the crash then lands in the *callee's* ARC prologue
  (`objc_storeStrong`), not at the real cause.

- **Non-ASCII in `prefix_selectors.py` input.** Wrong: a non-ASCII character (e.g. an em dash) in
  a comment of a `.m` file compiled through `tests/backports/host/prefix_selectors.py`. Right:
  keep comments in files on that pipeline ASCII-only. Reason: the tool renames selectors by byte
  offset from a clang AST dump, so one multi-byte UTF-8 character shifts every later offset and
  corrupts an unrelated selector further down the file (e.g. `component:fromDate:` becomes
  `ccharonHost_omponent:fromDate:`).

- **Mixing `NSInteger` and `NSUInteger`.** Wrong: subtracting an `NSUInteger` (e.g.
  `calendar.firstWeekday`) from a smaller `NSInteger` without a cast. Right: cast the `NSUInteger`
  side to `NSInteger` explicitly before subtracting. Reason: C's usual arithmetic conversions
  promote the signed side to unsigned, so the result wraps to a huge positive number instead of
  going negative - wrong answer, no crash, no warning.

- **`charon.libraries` and `verify_placed`.** Wrong: a `daemon`/`app`/`tweak` target
  `add_requires`s a backport package and `add_packages`s it, but link still fails with "these
  imports are not exported by the device's iOS ... neither the device nor this build provides".
  Right: add `set_values("charon.libraries", "<the alias add_requires gave the package>")` to the
  target. Reason: `modules/apple/platform.lua`'s `verify_placed` takes the plain, weak-linked path
  whenever `target:values("charon.libraries")` is empty and the target shares no runtime, and that
  path does not recognize the backport dylib as build-provided; `set_values` switches it to the
  branch that copies the library in and retargets the load command. Related trap: `@addon/charon/*`
  resolves to a version-pinned copy of this repository (`~/.xmake/addons/charon/<version>/`), not
  the working tree `add_repositories` points at, so an uncommitted edit under `modules/` never
  reaches a build that includes the addon by version - only a commit does.

- **`+load` in a backport.** Wrong: expecting `+load` to see a method the library's categories add,
  or replacing a release method there with no category carrying its selector. Right: decide on the
  release alone, and keep a same-selector category beside the replacement, as apple-backports'
  `Foundation/NSBundle+ReceiptURL.m` does. Reason: `+load` runs before `attach.c`'s constructor
  attaches `__DATA,__charon_catlist`, and the registry check counts only selectors categories add.

- **`git format-patch --no-walk` takes SHAs, not a range.** Wrong:
  `git format-patch --no-walk 716270c33..HEAD`, which makes git treat the whole `A..B` string as one
  literal revision: it writes a 0-byte file, and `git am` then fails with "Patch format detection
  failed" - measured on 2026-09-30, twice, by two different workers. Right: pass the SHAs as
  separate arguments (`git format-patch --no-walk <sha1> <sha2> ...`), or let the range walk itself
  (`git format-patch 716270c33..HEAD -o <dir>`), or `-1 HEAD~1..HEAD` for one commit. Check the
  byte size of every patch you wrote: a headerless or 0-byte file is this mistake, not a tool bug.

- **A shared registry file is edited by rows, never rewritten.** Wrong: an export whose diff on
  `packages/a/apple-backports/registry/**` touches hundreds of lines because the file was
  re-indented - 711 insertions against 708 deletions, 51/51, and 5488 of "differing" lines that
  differ only in one leading space, all measured on 2026-09-30 in three different families. Right:
  take the base revision of the file verbatim and re-apply only the row values that change, so the
  diff is those rows and nothing else. Reason: a shared file a patch rewrites merges today only
  while nobody else has opened it, so the series is one commit away from a conflict it did not
  cause, and the noise hides the real edit from every reader and from the review.

- **A seam the port owns needs a registry row only when it is an Apple API.** Wrong: adding a helper
  the test reads through a library class - `-[UIPasteboard charonRecordOptions:]` - and calling it
  "not API, it carries no release", which is what a reviewer's verdict said. Right: an Objective-C
  seam selector on an Apple class keeps its row, as `registry/MetalPerformanceShadersGraph/graph.json`
  does for its 13 `-[MPSGraph charon_mps_...]` rows, each `implemented`. A `charon_` C function that a
  library exports for another library of the package is different: it is not Apple API, so it has no
  row. It is declared with `CHARON_SEAM` before its return type, on a line of its own, in a header
  and in its definition, and `seam_symbols()` (modules/apple/backports.lua) reads that declaration so
  `link()` keeps the symbol exported. Reason: the registry is what the SDK declares; the gate counts a
  `charon_` name as internal, so such a row could only be unsatisfiable. A registered `charon_` C
  function is the failure the 6.1.3 gate reported as "listed as implemented, but nothing of that name
  is built", and the registry-check exception the other shape would need is the weakening this avoids.

- **A C function shared between backport files.** Wrong: calling from one file a C function defined
  in a file that implements a class or exports an API symbol. Right: define it in a file that exports
  no API symbol of its own, as `packages/a/apple-backports/UIKit/UIViewController+DocumentMenu.m`
  does, or link the files through Objective-C methods. Reason: a file whose exports a band's release
  already has is left out of that band, so the call is `Undefined symbols` in later bands only -
  `backports-gate` links one band and passes; only the all-band build of `canon-install` shows it.

- **The compiler cache behind a backports build.** Wrong: reading a hit rate as proof the build is
  the same, or setting the cache's key by hand for one run. Right: gate through
  `coordination/heavy.sh`, which exports `CCACHE_DIR` and `FLEET_HEAVY_CPUS` and writes
  `hash_dir = false` and `max_size` into `$CCACHE_DIR/ccache.conf`; the check for a cache is the
  objects it hands back against a `CCACHE_DISABLE=1` build, not the hit rate. Reason: the key is
  the preprocessed source and the compiler, plus the path of the source - and `hash_dir = false` is
  what makes that path relative, so every worktree reaches a source by the same name and shares one
  cache. At the default `hash_dir = true` the key carries each worktree's own directory instead, and
  every band builds alone with a cache that only ever misses: nothing fails, the fleet just keeps
  paying. `base_dir` is the weaker half of the same thing and buys nothing on its own. What ccache
  replays is the object the compiler wrote, so identity is a measurement - but measure it with
  callers that spell the source the same way every time. The key is path-independent and the object
  is not: a relative and an absolute spelling of one path are one key and two objects, and which one
  a build gets is decided by whichever job stored the entry first. Nothing a caller passes closes
  it: it is ccache's own `base_dir` rewrite of the `-c` argument, measured the same file three ways
  with nothing else in the way, and `-ffile-prefix-map` is the follow-up that would collapse both
  spellings and does not (`band-api-prefixmap`, `d2e15520`). What rooting the source against
  `opt.root` closes is the other half - two spellings from one caller - which is not this.
  `CCACHE_DISABLE` set at all, empty included, takes the cache out for a build that has to show its
  own work; `CCACHE` names a program and is checked before it is used, so a stale one costs the
  cache and not the build. `apple.cache` says which call sites are routed and names the one in
  `backports.lua`'s `releases_in()` that is not.
  No backport uses `__DATE__`/`__TIME__`, so no `time_macros` sloppiness is wanted: it would make a
  cached unit hand back another build's timestamp.

- **A job runner started from inside a job of xmake's own.** Wrong: calling `async.runjobs` - or
  anything else that runs jobs on xmake's scheduler - from inside a `package:on_install`, or from
  `write_deb()` which one calls. Right: let `backports.lua`'s `width()` see it and compile one unit
  at a time, which is what it does when `scheduler.co_count() > 1`. Reason: a runner started from
  inside a runner never returns. Measured: every object is written, nothing is printed, the process
  stays alive, and the run hangs there for good - on a shared scheduler and on an isolated one
  alike, so `isolate = true` is not the way out. It reads as a wedged build, not as a bug, and the
  compile output all exists, which is what makes it expensive to diagnose. A gate, `release-split`
  and the canon build run as the only coroutine of their own and are unaffected.

- **A working copy installed as the addon.** Wrong: a scratch project with `add_addons("charon")`
  whose `add_repositories` points at a worktree or a clone, run against the shared `~/.xmake`.
  Right: check a package or a module through `coordination/build-gate.lua`'s checkout argument, or
  inside a test that sets its own `XMAKE_GLOBALDIR`, as `tests/addon/store_test.lua` does. Reason: on xmake 3.1.1
  every addon install becomes the machine's `active` version, and every new project anywhere then
  locks that copy instead of the version it declares (`coordination/crutches.md`, the xmake addon
  lock entry); restoring it needs the coordinator.

- **Package source caches are patched.** Wrong: quoting what an upstream project does from the
  source tree a package build extracted (xmake's package cache, Conan's `p/*/s`). Right: read the
  pinned commit from a fresh download or the upstream git object, and say which one was read.
  Reason: both hold the tree after the recipe's patches and in-place edits ran.
