# Contributor guide

Orientation for anyone — human or AI assistant — working on this repository.
Read it before making changes. Task-specific playbooks live as skills under
revenant's `.agents/skills/` (webkit, device); this guide is
the map.

## What this is

A modern WebKit engine built from source for **armv7 / iOS 6.1.3** (iPhone 4S),
and the machinery that runs it. There are two ways the engine is used:

1. **Standalone app** — the engine hosted in this repo's own application
   (`examples/webview-host/`), which exists to exercise the engine directly. Built by
   `./xmakew build -P . RevWebViewHost`, against the prefixed variant of `webkit-engine`.
2. **Safari substitution** — the engine dropped underneath the phone's own Mobile
   Safari by a MobileSubstrate tweak. This is the current focus; the screenshots
   in the README are of it.

## The Safari substitution — three artifacts, do not confuse them

The engine lives in the dyld shared cache and cannot be swapped for one process.
A loader is injected into the launching app, sets `DYLD_FRAMEWORK_PATH` /
`DYLD_INSERT_LIBRARIES`, and re-execs; the second launch loads the port's engine.

| Source | Built by | On device | Job |
| --- | --- | --- | --- |
| `src/platform/safari/rev-safari-tweak.c` | target `RevSafari` | `/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib` | The **loader**: reads `InjectedApps`, re-execs enabled apps, skips SpringBoard. |
| `src/platform/safari/safari-compat.mm` | target `rev-safari-compat` | `/usr/lib/rev-safari-compat.dylib` | **Compat + hooks**: iOS 6 ABI stubs, bookmarks start page, WebAssembly, preference reads. Inserted by the loader. |
| `packages/w/webkit` and its patches | package `webkit-engine`, its `stage/usr/lib/rev-fw` | `/usr/lib/rev-fw/*.framework` | The WebKit engine itself. |

**The loader and the compat dylib are different files.** Deploying the compat
dylib over `RevSafari.dylib` (or vice versa) drops Safari to the system engine —
this has happened. The package puts each in its own place.

## The Settings pane

`src/platform/prefs/` builds `RevPrefs.bundle` — a native PreferenceBundle, built by
the `RevPrefs` target in `xmake.lua`, like the dylibs beside it — that writes the `space.kern0x1b.rev` preferences domain the engine reads
(`NewTabStartPage`, `CustomURLEnabled`, `CustomURL`, `InjectedApps`). System
`PSListController` cells are loaded from `src/platform/prefs/Resources/Root.plist`.

## Hard-won gotchas

- **A header change means a full build.** `ninja WebCore` builds one target;
  `WebKit.framework` and `WebKitLegacy.framework` embed WebCore types by value.
  Change a class's size in a WebCore header, deploy only the rebuilt WebCore, and
  those two frameworks read that type with the old layout. The symptom is not a
  crash log: the engine initialises cleanly, Safari's chrome draws with no text at
  all, and the process disappears with no REVCRASH line and no crash report. After
  any header change rebuild the whole `webkit-engine` package, which is what a
  change to the patch series does, then deploy.
- **Load-time undefined symbols.** A dylib that links clean (`ninja`/`clang`
  exit 0) can still fail to load on iOS 6, silently — dyld gives up and, for the
  Safari case, Safari falls back to the system engine. After building an injected
  dylib, check `nm -u <dylib> | c++filt` and match the linkage of the copy proven
  on device (`otool -L`). The compat dylib framework-links Foundation/CF/objc/
  sqlite; the loader links only libSystem + CoreFoundation.
- **An excluded engine source needs its feature gate off.** Wrong: dropping a
  file from the build (a `// ios6:` line in
  `Source/WebCore/SourcesCocoa.txt`) and aliasing its symbols to
  `webkitIOS6MediaEngineUnavailable` in `src/compat/ios6_media_stubs.cpp` while the
  `HAVE_*`/`ENABLE_*` gate that calls it stays on. Right: turn that gate off
  under `WEBKIT_IOS6` too, as `HAVE_AVASSETREADER` is in
  `Source/WTF/wtf/PlatformHave.h`. Reason: the alias returns `0` in a register
  and never writes a C++ return slot, so a live caller reads garbage and
  crashes away from the cause.
- **A new UIKit-delegate selector needs a default.** Wrong: sending a selector
  through `_UIKitDelegateForwarder` that only UIKit's own delegate implements.
  Right: also add it, empty, to `WebDefaultUIKitDelegate`
  (`Source/WebKitLegacy/ios/DefaultDelegates/`). Reason:
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
- **The engine is upstream plus a patch series** (`packages/w/webkit`). A change
  to the engine is a change to one of its patches, made in a scratch clone of
  WebKit at the base commit with the series applied, exported again with
  `git format-patch`, and its sha256 updated in the recipe. Never edit the
  fetched source in the package cache: the next fetch discards it.

## Conventions

- **No personal data in the repo.** The device address and password live only in
  `device.env` (gitignored). Never commit device credentials, IP addresses,
  hostnames, or absolute `/Users/<name>/...` paths — use `$HOME` /
  placeholders in scripts and docs.
- **Commit messages:** plain imperative subject describing the change. This is an
  openly AI-built public product — keep AI/tool attribution (the
  agent's own `Co-Authored-By:` trailer); we mark our work, we do not hide it.
- **Build artifacts** (`build/`, `*.dylib`, `*.a`, `*.log`) are
  gitignored and reproducible from the packages — do not commit them.
- **No pull requests to other people's repositories.** Fixes worth sending to WebKit collect in
  [upstream](../../reference/webkit/upstream.md); they go upstream once, as one batch, only after the engine is fully tested
  and only when the owner says so.

## Where to look

- Build: `./xmakew f -P . -p iphoneos -a armv7 && ./xmakew -P .` at the top of revenant;
  see [build and test](build-and-test.md). The engine's device filesystem tree is the `stage/` folder of
  the `webkit-engine` package.
- Package: `./xmakew deb -P .` writes `space.kern0x1b.rev_<version>_iphoneos-arm.deb`,
  engine frameworks included; `src/packaging/` holds only the `control` file and the
  `DEBIAN/postinst` script. The version is `version` in `xmake.lua`.
- Deploy: `./xmakew device install -P .` builds the package, runs `dpkg -i` on the phone
  `device.env` names, and refuses a .deb whose app would replace another bundle id.
  Claim the device first (`./xmakew device claim`).
- Tests: `tests/run-batteries.lua` and `tests/device/*.lua`, run with `./xmakew l`; the
  host tests are `./xmakew test -P .` after `./xmakew f -P . --webkit_host_tests=y`.
- Documentation: the guides beside this file, the explanations in [`docs/explanation/webkit/`](../../explanation/webkit/)
  and the reference in [`docs/reference/webkit/`](../../reference/webkit/). The [README](../../../frameworks/WebKit/README.md)
  has the index.
- Playbooks: revenant's `.agents/skills/webkit/SKILL.md` and `.agents/skills/device-session/SKILL.md`.

## Repository layout

```
examples/webview-host/  The standalone application: the embeddable host for the web view
src/                    The port's code: its packages, modules, compat library, platform targets and licence
  compat/       Symbols iOS 6 does not have, built into libios6compat.a
  device-tools/ The webkit-device-tools package: the phone's probes, their C sources and entitlements
  engine/       The webkit-engine package's recipe
  modules/      What the engine package does: options, checks, staging, the carry manifest
  packaging/    The package's control file and DEBIAN scripts
  platform/     The tweak, compat and TLS dylibs and the Settings bundle, xmake targets
    safari/     The Safari substitution: the loader, the compat/hooks, WebAssembly and TLS sources
    prefs/      The RevWebKit Settings PreferenceBundle
    device/     What is installed on the phone beside the engine
  LICENSE       The licence of the port's code, shipped in its packages
tests/          The numeric device suite, host tests, and JS conformance checks
  data/         Reference data the checks read: carry-manifest.txt, carry-symbols.txt, sdk-usage/, device.env.example
tools/          Diagnostic instruments on the device, and the maintenance scripts on the host
xmake.lua       The member: its packages, targets, checks and host tests
```

The documentation is at the top of revenant, in `docs/`. The engine itself is `packages/w/webkit`: an upstream commit
and the patch series, and the libraries iOS 6 cannot supply are packages beside it.
