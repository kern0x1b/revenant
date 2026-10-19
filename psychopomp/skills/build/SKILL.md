---
name: build
description: Build the app with Charon and xmake and read what the build says — the build loop with -y and a log file, where the bundle lands, the import check against the lowest release's own dyld shared cache, and how to read each failure — an import the release does not export (weak and strong), unimplemented selectors, a missing shared cache, the minimum raised by the linker, `Bad system call: 12`, two xmake processes locking each other, the addon version in use versus the one pinned or a Charon checkout's working tree, and a prompt waiting for -y. Use after the code is written, after every change to sources, xmake.lua or Info.plist, and whenever a build fails, hangs or the app dies with a bad system call.
---

# Build, and read what the build says

A green build here means more than compiled and linked: every binary is checked where it links
(Thumb interworking, `__PAGEZERO`, the minimum release it records, system calls the release
lacks) and the finished bundle is checked against the lowest release's own dyld shared cache —
every import must exist on that release. The SDK's headers are iOS 16.4 and say nothing about
what an old release has; that check is the truth.

Read `PROJECT.md` first. The skills `install`, `firmware` and `project` must have their evidence
there; if the shared cache for the lowest release is not held, the build asks to fetch it.

## 1. Build

```
xmake -y -v > .logs/build.log 2>&1; echo "exit $?"
```

- Always `-y`, always `-v`, always a log file, and wait for it. Without `-v` xmake prints only the
  first warning and replaces the rest with `warning: add -v for getting more warnings ..`; a log
  holding that line has not been read, build again with `-v`. The first build after `install` is quick; a
  build that adds a package (Swift runtime, Styx, backports) may build it from source first.
- `xmake -r -y -v` rebuilds the project's own files; `xmake f -c -y` re-resolves the
  configuration and packages after a change to `add_requires` or a package's configs (plain
  `xmake f` keeps the resolution it cached). Neither touches the shared store; nothing here needs
  `--force`.

How to know it worked, all three:

```
grep -n 'build ok' .logs/build.log
grep -n '^imports: ' .logs/build.log
grep -n 'warning: ' .logs/build.log
```

- `[100%]: build ok, spent …`
- `imports: every non-weak import of the armv7 slices of <n> binaries resolves against <m> exports`
  — the import check ran; its absence means it did not. It is printed while the bundle is
  checked, before `build ok`.
- no `warning: … weakly imports …`, no `warning: … sends … selector` and no
  `add -v for getting more warnings` line. xmake prints the warnings after `build ok`, all of
  them only with `-v`.

The bundle is `build/iphoneos/<arch>/release/<Name>.app`. Check it:

```
plutil -p build/iphoneos/armv7/release/<Name>.app/Info.plist   # CFBundleIdentifier, MinimumOSVersion
otool -l build/iphoneos/armv7/release/<Name>.app/<Name> | grep -A3 LC_VERSION_MIN_IPHONEOS
                                                                # version 6.0 (your apple_minimum)
ls build/iphoneos/armv7/release/<Name>.app                      # executable, Info.plist, your PNGs
```

Expected noise, not failures: `clang: warning: using sysroot for 'iOS 16.4' but targeting
'thumbv7-apple-ios6.0.0' [-Wincompatible-sysroot]` on every compile, and
`checking for Xcode SDK ... no` on a fresh configure.

Record in `PROJECT.md` under `## Progress` the build line: the log path, the `build ok` line and
the `imports:` line. Then follow the skill `emulate`.

## 2. Reading failures

### An import the release does not export

```
error: these imports are not exported by the device's iOS:
  <Name>  _SomeFunction (bound to /System/Library/Frameworks/UIKit.framework/UIKit)
```

The code calls a symbol the SDK declares but the lowest release does not have, strongly bound:
the app would fail to load. It is checked against the release named in `apple_minimum`, not the
SDK. Fix the code, not the check: use the API the release has (skill `objc` or `swift`), or a
backport that carries it (skill `backports`). Never raise `apple_minimum` without the user's say,
never silence availability warnings, never `-disable-availability-checking`.

`(loads <library>, which neither the device nor this build provides)` names a whole library the
release lacks and nothing in this build supplies: a shared-library target of the project not
bundled with `app.frameworks` (skill `project`), or the backports required under another alias
than `apple-backports` (skill `backports`).

### A weak import (warning now, refusal when packaged)

```
warning: <Name> weakly imports 1 symbol the armv7 release it is checked against does not export,
each of which is NULL there and must be called only behind a check for it: _OBJC_CLASS_$_MKLocalSearch
```

The compiler weak-linked a newer API because its declaration carries availability. It is NULL on
the device: every use must sit behind a check (`NSClassFromString`, `respondsToSelector:`, a
function pointer test, `#available` in Swift, skill `swift` §2). `xmake deb` refuses the image
unless the target says why every call is guarded: `set_values("charon.waive.weak-imports", "<the reason>")`. Write
that waiver only when every use of every symbol it covers is behind such a check, the user agreed,
and it is written under `## Limits` in `PROJECT.md` (skill `self-review`) — it records a guard the
static check cannot see; it is never a way to turn a refusal green. It covers the whole target: a
weak import added later is never refused, so read this warning's symbols on every build and ask the
user again for a new one (skill `objc`). A C call of the system library may instead come from
`charon@apple-compat` (skill `objc`). To see the packaging verdict without packaging, build as a
release:

```
CHARON_RELEASE=1 xmake -r -y -v > .logs/build-release.log 2>&1
```

For symbols the compiler emits itself (ARC entry points, the block runtime, emulated TLS, wide
atomics) the weak import is refused outright, naming what should have carried it: usually the
link lacks `-fobjc-arc` (skill `project`).

### A selector no class implements

```
warning: <Name> sends 1 selector no class of the armv7 release it is checked against implements,
which must run only behind respondsToSelector: or a version check: <selector>
```

Not a refusal. Put the send behind `respondsToSelector:` or a version check, or implement it
(a category). `xmake -v` lists all of them when there are more than twelve.

### The release's libraries are not held

`error: the imports of this armv7 build cannot be checked without the libraries of iOS 6.0; run
xmake firmware --arch=armv7 fetch 6.0` — the build asked to fetch them and got no yes. Run the
command it names (skill `firmware`) or build again with `-y`.

### The minimum was raised

`<file> records iOS 7.0, and this target builds for 6.0; the linker raised it, which it does when a
startup object such as crt1.3.1.o is missing` — something linked outside Charon's toolchain or SDK
package. Build every piece as a target of this project.

### `Bad system call: 12`

A process on the device or in the emulator dies with `Bad system call: 12` (SIGSYS; an emulator
verdict shows it as `crash(signal 12)`) before its own code runs. The binary was not built by
Charon's toolchain: a helper, test probe or tool compiled with the Mac's `clang`/`cc`, or taken
prebuilt from elsewhere. Rebuild it as a target in `xmake.lua` with Charon's rules (`app`, or
`daemon` for a command-line probe), same toolchain as the app, `-fobjc-arc` on compile and link.
By the symptom alone it cannot be told from a signing or sandbox rejection; check how the binary
was built first.

### Two xmake processes

A build making no progress for a long time: another `xmake` holds the lock, often one left over
from an earlier run in this project. A second build of the same project waits for the first
without a word; `the current project is being accessed by other processes, please wait!` is
printed only when the waiting command has `-D`. A package install that waits says
`package(<name>) is being accessed by other processes, please wait!`.

```
pgrep -fl xmake
```

Wait for it, or stop the one you started and no longer need. Never delete lock files in the
store. One exception, after a build was killed while fetching a package's sources: a leftover
`.git/index.lock` in that package's folder under `~/.xmake/cache/packages/` — remove that single
file and build again. `xmake` processes in other projects do not block this one except while
installing the same package.

### The addon in use is not the one pinned

The rules, the checks and `xmake deb` come from the addon installed at
`~/.xmake/addons/charon/<version>/`, chosen by `xmake-addons.lock`; the packages come from the
repository clone at `.xmake/macosx/arm64/repositories/charon`, at the `charon-repo-<X>` tag.

```
xmake addon --list | sed -n 2p                        # in the project: -> charon v<X>
grep 'version = "v' xmake-addons.lock
git -C .xmake/macosx/arm64/repositories/charon log --oneline -1
```

- The lock names another version: the build is not using the pinned Charon. Stop and tell the
  user; this is an xmake limit described in the skill `install` (its first trap), with no native
  fix yet. Do not edit the lock by hand.
- The user edits a clone of Charon to try a fix: the build does not see it. A tag is fetched
  from GitHub; even a local repository (`add_repositories("charon /path")` with
  `add_addons("charon latest")`) is installed from its last commit, so uncommitted edits never
  reach a build. Commit them in that clone first, and put the tag pin back before shipping.
- Something documented for Charon's `main` is missing: the pinned tag predates it. Say so; do
  not move the pin to `main` without the user.

### A prompt waiting for -y

A build or configure run without `-y`, from a script or an agent, stops at `… (pass -y to skip
confirm)?` or a firmware fetch question and waits forever. Stop it and run it again with `-y`.

### Other refusals

- `target(<Name>) adds package <p>, and nothing of it reached the target` → the package is added
  under a name its require does not carry; use the `alias` of `add_requires`.
- `<file> gives CFBundleExecutable <x>, and the application built is <Name>` → fix `Info.plist`.
- `target(<Name>) names resource <r>, and there is no such file or folder` → fix `app.resources`.
- `xmake found the project at <outer>, but this is the checkout at <here> nested inside it` →
  run `xmake -P .` in the nested checkout.

## Traps

- Reading only the last line → read the whole tail. Reason: weak-import and selector warnings are
  printed after `build ok`.
- Silencing a refusal with a waiver or a raised minimum → fix the call. Reason: the refusal is the
  device's own library list; the app would fail to load or crash where the symbol is NULL.
- `xmake require --force`, deleting under `~/.xmake/packages`, or a private `XMAKE_GLOBALDIR` to
  "fix" a build → never. Reason: a changed recipe is already a new install path; a private store
  rebuilds LLVM from source.
- Killing a long first build because the log is quiet → check `pgrep -fl 'clang|ninja|cmake'`.
  Reason: a compiler build prints nothing for long stretches.
- Starting a second `xmake` in the same project to "check progress" → never. Reason: the two lock
  each other and the second can stall the first.
