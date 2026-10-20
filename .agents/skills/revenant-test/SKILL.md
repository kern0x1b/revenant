---
name: revenant-test
description: Verify the Safari substitution and the Settings pane — run the WebKit port's host tests, batteries and device pages, confirm the port's engine is active on device, launch apps, drive the UI with revtouch, capture screenshots, and check SpringBoard health. Use after deploying or when checking a change on the iPhone 4S.
---

# Testing on device

Commands on the phone go through `./xmakew device -P . run "<cmd>"` with `device.env` at
the top of the checkout, after claiming the device with `./xmakew device claim` — see
`revenant-device` and `revenant-deploy`. Copying a file is `scp -P <DEVICE_PORT>` to
`root@<DEVICE_HOST>`, or the device module's `copy` and `fetch` from Lua.

## The tests

| Test | Needs | Runs |
| --- | --- | --- |
| host | nothing | `./xmakew f -P . --webkit_host_tests=y && ./xmakew test -P .`: `icu-sanity` and `icu-locales` against the trimmed ICU, built for this Mac |
| build checks | a build | run by the `webkit-engine` package itself: carry check, configure paths and project include, exports, compat audit, symbols, staged plists |
| gate | the device | `./xmakew l frameworks/WebKit/tests/device/run.lua` |
| batteries | the device and a build | `./xmakew l frameworks/WebKit/tests/run-batteries.lua` |
| the rest | the device | `gl-present.lua`, `gl-frame-rate.lua`, `share-sheet.lua`, `conformance.lua`, `sweep.lua` in `frameworks/WebKit/tests/device/` |

The device tests do not check the claim themselves.

After any change to the JavaScriptCore patches, run the batteries as well as the gate:
the gate's pages rarely keep a function hot enough to enter the DFG, so the gate can
stay green while every OSR entry into DFG code crashes; the batteries run
`tests/js/*.js` under `jsc` with the JIT tiers on. A 32-bit-only crash after taking
upstream code is first looked for among upstream commits that removed 32-bit branches,
in a scratch clone of WebKit: `git log -S '<removed line>' -- <file>`.

## Launching an app

- `/private/var/tmp/sblaunch <bundle-id>` where it is installed (the iPhone 4S); it is
  not on `PATH`.
- `uiopen <url>` otherwise — a web URL opens Safari, `prefs:root=...` opens Settings.

## Is the port's engine active?

The stock engine reports `AppleWebKit/536`; the port reports `AppleWebKit/605`.

- Open a page in Safari (`./xmakew device -P . run "uiopen https://…"`) and read the user
  agent — e.g. load a service that echoes it.
- Or read the on-device engine log:
  `./xmakew device -P . run "cat /tmp/rev-safari-stderr.log"` — the port prints
  `[tweak] ctor pass`, `WebKitInitialize`, `[jit] reservation … succeeded`.
- Or check what re-exec'd: `./xmakew device -P . run "cat /tmp/rev-safari-tweak.log"` — only
  apps enabled in `InjectedApps` (Safari by default) should appear.
- To start the engine log afresh, truncate it (`: > /tmp/rev-safari-stderr.log`);
  never `rm` it while Safari runs. The loader `freopen`s stderr onto that file,
  so a running Safari keeps writing to the unlinked inode and every later line
  is lost.

Ground truth of rendering: the stock engine renders modern Google/YouTube broken;
the port renders them correctly.

## Screenshots

`/usr/bin/shot` writes `/tmp/screenshot.png` (it ignores any path argument):

```sh
./xmakew device -P . -s 20 run 'sleep 8; /usr/bin/shot >/dev/null 2>&1'
scp -P <DEVICE_PORT> root@<DEVICE_HOST>:/tmp/screenshot.png ./shot.png   # then view it
```

Give heavy sites 15–30 s to finish; re-shoot if content is still loading.

## SpringBoard / UI health

```sh
./xmakew device -P . run 'launchctl list | grep com.apple.SpringBoard'   # present == running
```

`killall -0 SpringBoard` (exit 0 == running) works too. The device has no `ps`,
`head`, `tail`, `wc`, `uptime`, `nohup` or `timeout`; trim output on the host.
If unsure, take a screenshot; if the home screen renders, SpringBoard is fine.
The same pid in `launchctl list` across two checks means it is not
crash-looping.

## Memory breakdown (the device has no vmmap)

`tools/revmem.c` is a vmmap-lite: it sums a process's dirty/resident pages by VM
tag (CoreAnimation, CoreGraphics/ImageIO, JavaScriptCore, malloc, ...). The
`webkit-device-tools` package builds it with `revpid`, `revtouch` and
`raise-memory-limit`, each signed with the entitlements it needs, whenever the project is
configured for iphoneos. Copy it over and run as root:

```sh
scp -P <DEVICE_PORT> "$(./xmakew where -P . webkit-device-tools)/bin/revmem" root@<DEVICE_HOST>:/usr/bin/revmem
./xmakew device -P . -s 40 run "/usr/bin/revmem <mobilesafari-pid>"       # pid from launchctl list
```

Use it before any memory change to confirm which owner actually holds the dirty
pages — measured, the heavy pages are malloc/JS-heap bound, not pixel buffers.

## Measuring performance

- Turn every diagnostic switch off first (`WEBKIT_IOS6_*_LOG`, samplers, lock
  recorders). They pause the web thread and move results by a factor, not a
  percent.
- Clear `/tmp/rev-safari-stderr.log` before a run (truncate it, as above): the
  loader appends to it, so the previous launch's counters are still there.
- Measure the spread first. Two launches of the same build differ in time to
  first paint by more than most changes move it, so one run per build compares
  nothing: alternate builds, several runs each.
- Two sides of an experiment that agree to the last digit mean a stale file was
  read. Check the log's name and modification time.
- Read periodic counters over the whole log, not its `tail`: a counter printed
  and reset every few seconds shows only the last window, usually after the
  gesture ended.
- Symbolicate with the image bases printed by the same launch; ASLR moves them
  every launch.

## Driving the UI

`revtouch` (same package, `tools/revtouch.c`) injects touches in points, on a
320x480 screen unless `REVTOUCH_W` / `REVTOUCH_H` say otherwise:

```sh
scp -P <DEVICE_PORT> "$(./xmakew where -P . webkit-device-tools)/bin/revtouch" root@<DEVICE_HOST>:/usr/bin/revtouch
./xmakew device -P . run "revtouch tap 160 240"
./xmakew device -P . run "revtouch swipe 160 400 160 100"   # X Y X2 Y2
```

Verbs: `tap`, `down`, `move`, `up` take `X Y`; `swipe` takes `X Y X2 Y2`. Take a
screenshot first: launching an app does not make it frontmost.

## The Settings pane

Reload without a respring: `./xmakew device -P . run "killall Preferences; sleep 1; uiopen prefs:root=RevWebKit"`, then screenshot. The pane cannot be scrolled remotely —
ask a person at the device to scroll for the lower rows, or move a row to the top
temporarily to inspect it.
