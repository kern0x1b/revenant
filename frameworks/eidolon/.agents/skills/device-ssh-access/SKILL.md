---
name: device-ssh-access
description: Reach a real iOS 6 device from this repository — claim it, copy the demo or a probe over with device.lua, take device snapshots with device-shots.sh, and read "Permission denied" or connection-reset failures correctly. Use whenever Eidolon work needs hardware (not the emulator). The fleet discipline itself (claim, launch, tap, respring, privacy, cleanup) is the workspace skill `device-session`.
---

# Device access from Eidolon

The procedure for any device session — claiming, launching, touching, respring, privacy,
cleanup — is the workspace skill `device-session`: read
`$HOME/Git/projects/ios/.agents/skills/device-session/SKILL.md` first. This file only adds what
is specific to Eidolon.

## Claim

`xmake device` runs in any directory holding a `device.env` (or `device.NAME.env`). Eidolon has
no root xmake project and keeps no `device.env` (`rtpkg/` has none either), so claim from a
directory that has one — the shared charon checkout, or the `DEVICE_ROOT` of `local.env`:

```
export CHARON_DEVICE_HOLDER=<task>
cd $HOME/Git/projects/ios/charon            # or "$DEVICE_ROOT"
xmake device list
xmake device --minutes=30 claim             # -d NAME (or CHARON_DEVICE=NAME) picks device.NAME.env
```

A claim without a holder errors; `run` and the rest check the claim through
`CHARON_DEVICE_HOLDER` only, so keep it exported for the whole session. `xmake device` has no
copy or fetch action: its actions are install, uninstall, log, run, where, list, claim, release.

## Copy, fetch, run: device.lua

```
export CHARON_MODULES=$HOME/Git/projects/ios/charon/modules
set -a; . $HOME/Git/projects/ios/charon/device.env; set +a     # DEVICE_HOST/PORT/UDID/PASSWORD
xmake l device.lua copy <local> <remote>
xmake l device.lua fetch <remote> <local>
xmake l device.lua run "<command>" [SECONDS]
xmake l device.lua log [SECONDS]
```

`device.lua` imports charon's `device` module from `CHARON_MODULES` and reads the phone only from
the `DEVICE_*` environment variables, never from a `device.env`; the module still checks the claim
against `CHARON_DEVICE_HOLDER`.

## Device snapshots: device-shots.sh

```
./device-shots.sh [--live | --gesture] SCENARIO...
```

It installs `eidolon/out/EidolonDemo.app`, renders each scenario in the app and fetches the
results into `device-shots/` (git-ignored). It reads `DEVICE_ROOT` (a Charon port directory whose
`device.env` names the phone) and `CHARON_DEVICE_HOLDER` from `local.env`, and talks to the phone
through the Conan CLI `charon --root "$DEVICE_ROOT" device run|copy|fetch`, which checks no claim:
claim with `xmake device` first.

## Traps

- "Permission denied (publickey,password,...)" from a raw `ssh`/`scp` to a guessed port means the wrong device, not the wrong password: `pgrep -fl iproxy` shows which UDID each tunnel serves.
- `kex_exchange_identification: Connection reset` is the USB tunnel or dropbear rate-limiting: slow down and retry; it is not a crash.
- `launchctl list | grep com.apple.SpringBoard` is the liveness check; the device's `ps ax | grep` is not reliable.
- `/usr/bin/shot` always writes `/tmp/screenshot.png`, whatever path it is given.
- No UDID, address, hostname or password in a tracked file, commit or skill; `alpine`, the public jailbreak default, is the only credential that may be named.
