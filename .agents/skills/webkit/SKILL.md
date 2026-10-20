---
name: webkit
description: Use when building, deploying, testing or debugging the WebKit port's Safari substitution in frameworks/WebKit (the loader, the compat dylib, TLS, the WebKit engine and the RevWebKit Settings pane) on a jailbroken iPhone 4S running iOS 6: the armv7 build and .deb, installing it on the phone, its device tests, and diagnosing a Safari that fell back to the system engine, a dylib that will not load, or a page that misbehaves.
---

# WebKit Safari substitution

The project is `frameworks/WebKit/`. `docs/guides/webkit/contributing.md` maps the three artifacts (the loader `RevSafari`, the compat dylib `rev-safari-compat`, the engine in the `webkit-engine` package), and `docs/guides/webkit/build-and-test.md` has the whole build sequence. This skill is the procedure. Run from the top of revenant with `./xmakew`. Target: armv7, iOS 6.0 deployment, built against the iOS 16.4 SDK that the toolchain fetches.

## Build

- `./xmakew f -P . -p iphoneos -a armv7`, then `./xmakew -P .`: the engine packages, the tweaks and the Settings bundle.
- `./xmakew deb -P .` writes `space.kern0x1b.rev_<version>_iphoneos-arm.deb` under `build/`. `version` is in `frameworks/WebKit/xmake.lua`.
- `./xmakew build -P . RevWebViewHost` builds the standalone app, which uses the `prefixed` variant of `webkit-engine`. The phone uses `system`.
- The engine is upstream WebKit at one commit plus `third_party/webkit/patches/`. A change to the engine is a change to a patch: in a scratch clone at the base commit under `$HOME/.revenant/cache/<task>/`, `git am` the series, make the change in its commit, `git format-patch` the series back into `third_party/webkit/patches/`, and put the new sha256 in `third_party/webkit/xmake.lua`. Never edit the fetched source in the package cache; the next fetch discards it.
- A change to a WebCore header needs the whole `webkit-engine` rebuilt. A partial build loads and misbehaves with no crash log.
- Before deploying a dylib, check it in the build output: `otool -L` and `nm -u FILE | c++filt`. The loader links only libSystem and CoreFoundation. The compat dylib framework-links Foundation, CoreFoundation, objc and sqlite. Keep each install name equal to its deployed path, and do not link either with `-undefined dynamic_lookup`.

## Deploy

1. `cp frameworks/WebKit/tests/data/device.env.example device.env` at the top, then set `DEVICE_HOST`, `DEVICE_PORT` and, over USB, `DEVICE_UDID`. The file is gitignored.
2. Claim the phone first: `./xmakew device claim` (see the `device` skill).
3. `./xmakew device install -P .` builds and stages the substitution, writes the .deb, copies it to the phone and runs `dpkg -i`. It refuses a .deb whose app would replace an installed app with another bundle id.

| In the package | On the phone |
| --- | --- |
| loader and `RevSafari.plist` | `/Library/MobileSubstrate/DynamicLibraries/` |
| compat and hooks | `/usr/lib/rev-safari-compat.dylib` |
| TLS | `/usr/lib/rev-TLS.dylib` |
| engine | `/usr/lib/rev-fw/{JavaScriptCore,WebCore,WebKit}.framework` |
| C++ runtime | `/usr/lib/librev-c++.1.dylib`, `/usr/lib/librev-c++abi.1.dylib` |
| Settings pane | `/Library/PreferenceBundles/RevPrefs.bundle`, `/Library/PreferenceLoader/Preferences/RevWebKit.plist` |

- The loader and the compat dylib are different files. Copying one over the other drops Safari to the system engine.
- Installing keeps no backup. Keep the last good .deb, copy it out of `build/`, and to go back `scp` it to the phone as `/tmp/rev.deb` and run `./xmakew device -s 300 run "dpkg -i /tmp/rev.deb && rm -f /tmp/rev.deb"`.
- No respring is needed. The package's `postinst` kills MobileSafari and Preferences, and a respring re-locks the phone.
- Settings pane changes: `./xmakew device run "killall Preferences; sleep 1; uiopen prefs:root=RevWebKit"`.

## Test

- Host, on this Mac: `./xmakew f -P . --webkit_host_tests=y`, then `./xmakew test -P .` (`icu-sanity`, `icu-locales`).
- Batteries on the phone: `./xmakew l frameworks/WebKit/tests/run-batteries.lua [BATTERY...]` runs `tests/js` under `jsc` with the engine just built.
- Device pages: `./xmakew l frameworks/WebKit/tests/device/run.lua [HOST] [--port N]` loads each test page in Safari on the phone and prints its verdict. HOST is this Mac's address as the phone reaches it.
- Other device checks (`gl-present.lua`, `gl-frame-rate.lua`, `share-sheet.lua`, `conformance.lua`, `sweep.lua`) are in `tests/device/`; its README says what each one measures.
- After a change to the JavaScriptCore patches, run the batteries as well as the pages. Pages rarely keep a function hot enough to reach DFG, so they can pass while every OSR entry into DFG code crashes.
- Ground truth for rendering: the stock engine renders modern Google and YouTube pages broken, and the port renders them.
- The Settings pane cannot be scrolled remotely. Move a row to the top to inspect it, or have someone at the phone scroll.

Confirm the port's engine is active:

- The user agent reads `AppleWebKit/605`; the stock engine reports `536`.
- `/tmp/rev-safari-stderr.log` has `[tweak] ctor pass`, and `/tmp/rev-safari-tweak.log` has a `re-exec` line for each app in `InjectedApps` (Safari by default).
- To start a log afresh, truncate it with `: > FILE`. Never delete it while Safari runs: the loader holds it open, and later lines are lost.

Driving the UI and measuring: the `webkit-device-tools` package builds `revtouch`, `revmem`, `revpid` and `raise-memory-limit` (`docs/reference/webkit/tools.md`). `./xmakew where -P . webkit-device-tools` prints its folder; `scp` `bin/revtouch` to `/usr/bin` on the phone, then `./xmakew device run "revtouch tap 160 240"` or `revtouch swipe X Y X2 Y2`. Coordinates are points on a 320x480 screen unless `REVTOUCH_W` and `REVTOUCH_H` say otherwise. Take a screenshot first, because launching an app does not make it frontmost. `revmem <pid>` sums dirty pages by VM tag; the phone has no vmmap.

Performance measurements:

- Turn off the diagnostic switches (`WEBKIT_IOS6_*_LOG`, samplers, lock recorders) first. They change results by a factor.
- Truncate the log before each run.
- Measure the spread before comparing: two launches of one build differ by more than most changes. Alternate the builds and run each several times.
- Read periodic counters over the whole log, not its tail.

## Debug

Safari is on the system engine (`AppleWebKit/536`):

1. `./xmakew device run "cat /tmp/rev-safari-tweak.log"`. With no `re-exec ... MobileSafari` line, the loader did not re-exec Safari: Safari is not in `InjectedApps`, or the loader did not load.
2. `./xmakew device run "ls -la /Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib /usr/lib/rev-safari-compat.dylib"`. The compat dylib is much larger than the loader; a swapped pair shows here.
3. Fetch the on-device dylib and compare its `otool -L` with the build's. dyld refuses a dylib whose linkage differs from the proven copy, and says nothing.

Anything inserted into Mobile Safari lives under `/usr/lib`, never `/var/mobile`: a SpringBoard-launched Safari runs in a sandbox that refuses libraries from `/var/mobile`. Launched as root over ssh there is no sandbox, so a test that way hides the failure.

A page misbehaves: enable Settings, RevWebKit, Diagnostics, Log page console (`ConsoleLog` in the `space.kern0x1b.rev` domain). The compat dylib then turns on WebKit's page-message logging when Safari starts. Relaunch Safari, load the page and read `/tmp/rev-safari-stderr.log`, which has each message's file and line. Turn it off afterwards; a chatty page writes a lot. To flip it over ssh, fetch `/var/mobile/Library/Preferences/space.kern0x1b.rev.plist`, set `ConsoleLog` with `plutil -replace ConsoleLog -bool YES`, copy it back, and run `killall cfprefsd MobileSafari`.

A symptom after a change of the port's own:

- Suspect the port first. List the port's changes that could produce it (the patches in `third_party/webkit/patches` that touch `Source/<area>`, `grep -rn WEBKIT_IOS6` in the patched tree, `app/`, `compat/`, `platform/`), and rule each out by measurement before blaming the site, upstream WebKit or the phone.
- Diagnostics never run on a per-frame or per-event path: no `fopen`, `getenv`, `dladdr`, `sleep` or JavaScript evaluation there. Gate them behind a `/tmp/native-*` switch file, off by default, with the `access()` result cached in a `static`.
- When the screen disagrees with a metric, measure what the eye sees, such as a layer's position in window coordinates, and compare it with a fresh screenshot.

A SIGSEGV in `IMGSGX543GLDriver` after `malloc: mmap(size=...) failed (error code=12)` is address-space exhaustion near the memory ceiling, not the change under test. The lever is peak resident memory.

A device that looks dead, or an ssh connection reset: see the `device` skill.

Recovery: reinstall the last good .deb (see Deploy). If the phone is stuck, boot into safe mode by holding Volume Up during boot; MobileSubstrate is off there, so you can ssh in and revert. Screenshots and liveness checks: the `device` skill.
