---
name: deploy
description: Push the Safari substitution and the RevWebKit Settings pane to a jailbroken iPhone 4S over SSH, safely and reversibly. Use when installing or updating the tweak on device.
---

# Deploying to the device

## Configure the device address (never committed)

```sh
cp device.env.example device.env
# set DEVICE_HOST, DEVICE_PORT, DEVICE_PASSWORD in device.env (gitignored)
```

Charon reads it: `charon device run <timeout> "<cmd>"`,
`charon device copy <local> <remote>` and `charon device fetch <remote> <local>`.
Scripts import it instead of building SSH option strings of their own.
Claim the device before any of this; `charon device` does not check claims — see
`.agents/skills/device-ssh-access`.

## Push everything

`charon build` stages the whole substitution; one command packs and installs it:

```sh
charon install
```

It runs `charon package` (which copies the .deb into `build/<variant>/` and
prints `package <path>`), copies each .deb to `/tmp` on the phone, runs
`dpkg -i <deb> && rm -f <deb>`, refuses a .deb whose `/Applications/<App>.app`
would replace an installed app with another bundle id, and runs
`su mobile -c uicache` when the package holds an app. The package's
`packaging/DEBIAN/postinst` kills Mobile Safari and Preferences; no respring is
needed.

For the engine alone, without rebuilding the package:

```sh
charon deploy
```

It backs up each framework binary to `/usr/lib/rev-fw.bak/<Framework>`, copies
the binaries and streams their resources, fails if AppleDouble `._*` files
landed on the phone, and then runs only `killall MobileSafari` — no postinst, so
kill Preferences yourself if the pane depends on the change.

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
- **Keep `/usr/lib/rev-fw.bak/`**: only `charon deploy` makes it, and it holds the
  engine binaries it replaced. `charon install` keeps no backup; the way back
  there is reinstalling an earlier .deb — see `.claude/skills/debug`.
- **Iterating on the Settings pane needs no respring:** redeploy the bundle, then
  `charon device run 15 "killall Preferences"` and reopen it. A respring re-locks the
  device.

## After deploying

Respring with `charon device run 15 "killall SpringBoard"`, wait for it to come back
(`launchctl list | grep com.apple.SpringBoard`), then verify — see
`.claude/skills/test`.

## Proving the phone holds this build

The stage differs from the build tree by design: it strips local symbols
(`strip -S -x`; WebCore is about half the size staged), retargets install names
and re-signs each binary, renames per `as` (`WebKitLegacy.framework` is staged as
`WebKit.framework`), turns plists binary (`stage:plists-to-binary`) and copies
resources only where `resources = true` (WebCore). Size and md5 compare only
within one side — stage against phone. Across tree and stage compare what
survives strip and re-signing:

```sh
otool -l FILE | awk '$1=="uuid"{print $2; exit}'   # LC_UUID; the line after LC_UUID is cmdsize
nm -gU FILE | wc -l                                  # exported symbol count
```

Compare plists by parsed content (`plistlib`), never by bytes.
