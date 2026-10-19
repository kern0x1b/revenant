# Contributor guide

Orientation for anyone — human or AI assistant — working on this repository.
Read it before making changes. Task-specific playbooks live as skills under
`.agents/skills/` (build, deploy, test, debug, device-ssh-access); this file is
the map.

## What this is

A modern WebKit engine built from source for **armv7 / iOS 6.1.3** (iPhone 4S),
and the machinery that runs it. There are two ways the engine is used:

1. **Standalone app** — the engine hosted in this repo's own application
   (`app/`), which exists to exercise the engine directly. Built by
   `charon build --variant prefixed`.
2. **Safari substitution** — the engine dropped underneath the phone's own Mobile
   Safari by a MobileSubstrate tweak. This is the current focus; the screenshots
   in the README are of it.

## The Safari substitution — three artifacts, do not confuse them

The engine lives in the dyld shared cache and cannot be swapped for one process.
A loader is injected into the launching app, sets `DYLD_FRAMEWORK_PATH` /
`DYLD_INSERT_LIBRARIES`, and re-execs; the second launch loads the port's engine.

| Source | Built to | On device | Job |
| --- | --- | --- | --- |
| `platform/safari/rev-safari-tweak.c` | `build/system/stage/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib` | `/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib` | The **loader**: reads `InjectedApps`, re-execs enabled apps, skips SpringBoard. |
| `platform/safari/safari-compat.mm` | `build/system/stage/usr/lib/rev-safari-compat.dylib` | `/usr/lib/rev-safari-compat.dylib` | **Compat + hooks**: iOS 6 ABI stubs, bookmarks start page, WebAssembly, preference reads. Inserted by the loader. |
| the engine build | `build/system/stage/usr/lib/rev-fw` | `/usr/lib/rev-fw/*.framework` | The WebKit engine itself. |

**The loader and the compat dylib are different files.** Deploying the compat
dylib over `RevSafari.dylib` (or vice versa) drops Safari to the system engine —
this has happened. The package puts each in its own place.

## The Settings pane

`platform/prefs/` builds `RevPrefs.bundle` — a native PreferenceBundle, built by
CMake that Charon writes from `charon.toml`, like the dylibs beside it — that writes the `space.kern0x1b.rev` preferences domain the engine reads
(`NewTabStartPage`, `CustomURLEnabled`, `CustomURL`, `InjectedApps`). System
`PSListController` cells are loaded from `platform/prefs/Resources/Root.plist`.

## Hard-won gotchas

- **A header change means a full build.** `ninja WebCore` builds one target;
  `WebKit.framework` and `WebKitLegacy.framework` embed WebCore types by value.
  Change a class's size in a WebCore header, deploy only the rebuilt WebCore, and
  those two frameworks read that type with the old layout. The symptom is not a
  crash log: the engine initialises cleanly, Safari's chrome draws with no text at
  all, and the process disappears with no REVCRASH line and no crash report. After
  any header change run the full `charon build`, which builds everything, then
  deploy.
- **Load-time undefined symbols.** A dylib that links clean (`ninja`/`clang`
  exit 0) can still fail to load on iOS 6, silently — dyld gives up and, for the
  Safari case, Safari falls back to the system engine. After building an injected
  dylib, check `nm -u <dylib> | c++filt` and match the linkage of the copy proven
  on device (`otool -L`). The compat dylib framework-links Foundation/CF/objc/
  sqlite; the loader links only libSystem + CoreFoundation.
- **An excluded engine source needs its feature gate off.** Wrong: dropping a
  file from the build (a `// ios6:` line in
  `webkit-254/Source/WebCore/SourcesCocoa.txt`) and aliasing its symbols to
  `webkitIOS6MediaEngineUnavailable` in `compat/ios6_media_stubs.cpp` while the
  `HAVE_*`/`ENABLE_*` gate that calls it stays on. Right: turn that gate off
  under `WEBKIT_IOS6` too, as `HAVE_AVASSETREADER` is in
  `Source/WTF/wtf/PlatformHave.h`. Reason: the alias returns `0` in a register
  and never writes a C++ return slot, so a live caller reads garbage and
  crashes away from the cause.
- **A new UIKit-delegate selector needs a default.** Wrong: sending a selector
  through `_UIKitDelegateForwarder` that only UIKit's own delegate implements.
  Right: also add it, empty, to `WebDefaultUIKitDelegate`
  (`webkit-254/Source/WebKitLegacy/ios/DefaultDelegates/`). Reason:
  `_WebSafeForwarder` answers `respondsToSelector:` and
  `methodSignatureForSelector:` from its default target only, so without the
  default the send raises an unrecognized selector.
- **SpringBoard is boot-critical.** The Substrate filter is broad
  (`Filter { Classes = UIApplication }`) so the loader reaches every app, but the
  loader returns immediately for SpringBoard (`getprogname`) and no-ops for any
  app not enabled in `InjectedApps`. Never let injection touch SpringBoard.
- **Checking whether SpringBoard is alive:** use `launchctl list | grep
  com.apple.SpringBoard` or `killall -0 <process>`. The device has no `ps`,
  `head`, `tail`, `wc`, `uptime`, `nohup` or `timeout`; trim output on the host.
  Take a `/usr/bin/shot` screenshot to confirm the UI.
- **Iterating on the Settings pane** needs no respring: redeploy the bundle, then
  `killall Preferences` and reopen. A respring re-locks the device.
- **`/usr/bin/shot`** always writes `/tmp/screenshot.png` and ignores any path
  argument.
- **The engine is a git submodule** (`webkit-254/`) on the fork's `main` branch.
  Commit and push are forward-only safe; `git checkout`/`reset` inside it can
  destroy the port. Never do destructive git there.

## Conventions

- **No personal data in the repo.** The device address and password live only in
  `device.env` (gitignored). Never commit device credentials, IP addresses,
  hostnames, or absolute `/Users/<name>/...` paths — use `$HOME` /
  placeholders in scripts and docs.
- **Commit messages:** plain imperative subject describing the change. This is an
  openly AI-built public product — keep AI/tool attribution (the
  agent's own `Co-Authored-By:` trailer); we mark our work, we do not hide it.
- **Build artifacts** (`build/`, `*.dylib`, `*.a`, `*.log`) are
  gitignored and reproducible from the recipe — do not commit them.
- **No pull requests to other people's repositories.** Fixes worth sending to WebKit collect in
  `docs/upstream.md`; they go upstream once, as one batch, only after the engine is fully tested
  and only when the owner says so.

## Where to look

- Build: `charon build` (`charon build --variant prefixed` for the standalone application's engine); see `docs/building.md`. It ends with the device filesystem tree in `build/system/stage`.
- Package: `charon package` copies
  `space.kern0x1b.rev_<version>_iphoneos-arm.deb`, engine frameworks included,
  into `build/<variant>/` and prints `package <path>`; `packaging/` holds only
  the `control` file and the `DEBIAN/postinst` script. The version is `version`
  in `charon.toml`.
- Deploy: `charon install` packages, copies each .deb to `/tmp`, runs
  `dpkg -i … && rm`, refuses a .deb whose app would replace another bundle id,
  and runs `su mobile -c uicache` when the package holds an app; `charon deploy`
  for the engine alone. Claim the device first (`device-ssh-access`).
- Documentation: `docs/` (`architecture.md`, `network.md`, `compatibility.md`, `building.md`, `memory-and-caches.md`).
- Playbooks: `.agents/skills/{build,deploy,test,debug,device-ssh-access}/SKILL.md`.
- Workspace-wide procedures are skills in `$HOME/Git/projects/ios/.agents/skills/`: `device-session` (claim, run, install, launch, tap on a real device), `canon-install`, `patch-merge`, `worktree-sweep`, `session-handoff`, `band-launch`, `band-supervise`. A session started inside this repository does not list them — read `<name>/SKILL.md` there.
