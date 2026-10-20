---
name: revenant-deploy
description: Push the Safari substitution and the RevWebKit Settings pane to a jailbroken iPhone 4S over SSH, safely and reversibly. Use when installing or updating the tweak on device.
---

# Deploying to the device

## Configure the device address (never committed)

```sh
cp frameworks/WebKit/device.env.example device.env
# set DEVICE_HOST, DEVICE_PORT (and DEVICE_UDID over USB) in device.env at the top of the checkout (gitignored)
```

The toolchain's device module reads it: `./xmakew device -P . run "<cmd>"` from a shell,
and `run`, `copy` and `fetch` from Lua, as the tests in `frameworks/WebKit/tests/` do.
Scripts use the module instead of building SSH option strings of their own.
Claim the device before any of this with `./xmakew device claim` — see `revenant-device`.

## Push everything

```sh
./xmakew device install -P .
```

It builds and stages the whole substitution, writes the `.deb`, runs `dpkg -i` on the phone
and refuses a .deb whose `/Applications/<App>.app` would replace an installed app with
another bundle id. The package's `packaging/DEBIAN/postinst` kills Mobile Safari and
Preferences; no respring is needed.

There is no engine-only push any more: the engine is part of the one package, and
installing it is how the phone gets a new engine.

The package puts each file where it belongs:

| In the package | Device |
| --- | --- |
| the loader | `/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib` and `RevSafari.plist` |
| compat and hooks | `/usr/lib/rev-safari-compat.dylib` |
| TLS | `/usr/lib/rev-TLS.dylib` |
| the engine | `/usr/lib/rev-fw/{JavaScriptCore,WebCore,WebKit}.framework` |
| the C++ runtime | `/usr/lib/librev-c++.1.dylib`, `/usr/lib/librev-c++abi.1.dylib` |
| the Settings pane | `/Library/PreferenceBundles/RevPrefs.bundle`, `/Library/PreferenceLoader/Preferences/RevWebKit.plist` |

## Rules that keep the device bootable

- **Never overwrite the loader with the compat dylib or vice versa** — they are
  different files; swapping them drops Safari to the system engine.
- **Keep the previous .deb**: installing keeps no backup, and the way back is
  reinstalling an earlier package — see `revenant-debug`. A `/usr/lib/rev-fw.bak/`
  an older engine-only push left on the phone still holds the binaries it replaced.
- **Iterating on the Settings pane needs no respring:** reinstall, then
  `./xmakew device -P . run "killall Preferences"` and reopen it. A respring re-locks the
  device.

## After deploying

Respring with `./xmakew device -P . run "killall SpringBoard"`, wait for it to come back
(`launchctl list | grep com.apple.SpringBoard`), then verify — see `revenant-test`.

## Proving the phone holds this build

The stage differs from the build tree by design: it strips local symbols
(`strip -S -x`; WebCore is about half the size staged), retargets install names
and re-signs each binary, renames `WebKitLegacy.framework` to `WebKit.framework`,
turns plists binary and copies resources only for WebCore. Size and md5 compare only
within one side — stage against phone. Across tree and stage compare what
survives strip and re-signing:

```sh
otool -l FILE | awk '$1=="uuid"{print $2; exit}'   # LC_UUID; the line after LC_UUID is cmdsize
nm -gU FILE | wc -l                                  # exported symbol count
```

Compare plists by parsed content (`plutil -convert json -o - FILE`), never by bytes.
