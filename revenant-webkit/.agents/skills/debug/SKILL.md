---
name: debug
description: Diagnose and recover the Safari substitution on device — Safari fell back to the system engine, an injected dylib will not load, a page misbehaves and its console is needed, a symptom or crash follows a change, the device SSH is unresponsive, or SpringBoard looks down. Use when something on the iPhone 4S is broken.
---

# Debugging on device

## Safari is on the system engine (`AppleWebKit/536`)

The loader did not re-exec Safari, or the engine did not load. Check in order:

1. `charon device run 12 "cat /tmp/rev-safari-tweak.log"` — is there a
   `re-exec …MobileSafari` line? No line → the loader bailed (Safari disabled in
   `InjectedApps`, or the loader failed to load).
2. Confirm the two dylibs are the right files and sizes:
   `charon device run 12 "ls -la /Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib /usr/lib/rev-safari-compat.dylib"`.
   A common mistake is deploying the compat dylib over `RevSafari.dylib` — the
   loader is small; the compat dylib is much larger (bundles WASM).
3. Compare the on-device dylib's linkage to the local build: pull it back and run
   `otool -L`. A dylib linked against an SDK dependency whose iOS 6 compatibility
   version is lower will be **refused by dyld silently**. Match the linkage of the
   proven copy (see `.claude/skills/build`).

## An injected dylib will not load

`otool -L <dylib>` and `nm -u <dylib> | c++filt`. Fixes:

- The loader must link only `libSystem` + `CoreFoundation`.
- The compat dylib must framework-link Foundation/CoreFoundation/objc/sqlite with
  install_name `/usr/lib/rev-safari-compat.dylib`.
- Keep each dylib's `install_name` equal to its deployed path.
- Anything inserted into Mobile Safari lives under `/usr/lib`, never under
  `/var/mobile`: launched by SpringBoard, Safari runs in its sandbox, whose
  profile refuses to load a library from `/var/mobile`. Launched over SSH as
  root it has no sandbox, so a test that way hides the failure.

## A page misbehaves: read its console

Settings → RevWebKit → Diagnostics → **Log page console** (`ConsoleLog` in the
`space.kern0x1b.rev` domain) makes the compat dylib turn on WebKit's
`LogsPageMessagesToSystemConsoleEnabled` when Safari starts — no engine rebuild.
Relaunch Safari, load the page, then read
`charon device run 12 "cat /tmp/rev-safari-stderr.log"`: console messages and
uncaught errors appear with their file and line.

The row sits below what a remote session can scroll to. To flip it remotely:
`charon device fetch /var/mobile/Library/Preferences/space.kern0x1b.rev.plist <local>`,
set `ConsoleLog` with Python's `plistlib`, `charon device copy` it back, then
`charon device run 12 "killall cfprefsd MobileSafari"`. Turn it off afterwards:
a chatty page writes a lot.

## A symptom after a change of the port's own

- Suspect the port's own code first: list the port changes that could produce
  the symptom (`grep -rn WEBKIT_IOS6 webkit-254/Source/<area>`, plus `app/`,
  `compat/`, `platform/`) and rule each out by measurement before blaming the
  site, upstream WebKit or the device.
- Diagnostics never run unconditionally on a per-frame or per-event path: no
  `fopen`/`fprintf`, `getenv`, `dladdr`, `sleep` or JavaScript evaluation there.
  Put them behind a `/tmp/native-*` switch file, off by default, with the
  `access()` result cached in a `static`, as the existing switches do.
- When what is on screen disagrees with a metric, the metric measures the wrong
  quantity: measure what the eye sees (for a layer, its absolute position in
  window coordinates) and compare it with a fresh screenshot.

## A crash inside the graphics driver on a heavy page

A SIGSEGV in `IMGSGX543GLDriver` (`gldUpdateDispatch`, null `r0`) preceded in
the log by `malloc: mmap(size=…) failed (error code=12)` is address-space
exhaustion near the memory ceiling, not a regression in the change under test.
The engine uses the system allocator; when libmalloc cannot map a new region
`malloc` returns NULL, and the first caller that does not check is the GPU
driver. It follows load, not a site; the lever is peak resident memory.

## The device looks dead / SSH resets

See `.agents/skills/device-ssh-access` for the liveness check, the screenshot probe, and how to
read a connection-reset — the tunnel/USB mechanics there apply here unchanged.

## Recover to the last good state

Nothing on the device keeps a copy of the loader or the compat dylib. The ways
back:

- **Anything the .deb installed:** reinstall an earlier .deb (`charon package`
  leaves each version it builds in `build/<variant>/`):
  `charon device copy build/system/space.kern0x1b.rev_<version>_iphoneos-arm.deb /tmp/rev.deb`,
  then `charon device run 300 "dpkg -i /tmp/rev.deb && rm -f /tmp/rev.deb"`.
- **The engine after `charon deploy`:** it left the replaced binaries in
  `/usr/lib/rev-fw.bak/<Framework>`; copy each back and restart Safari:

```sh
charon device run 30 'cd /usr/lib/rev-fw.bak && for fw in *; do cp -f "$fw" "/usr/lib/rev-fw/$fw.framework/$fw"; done; killall MobileSafari'
```

If a bad **broad** injection makes the UI misbehave, reinstalling a good
package and respringing brings it back; the loader guards SpringBoard, so
the phone stays bootable. If ever truly stuck, booting into **safe mode** (hold
Volume Up during boot) disables MobileSubstrate so you can SSH in and revert.
