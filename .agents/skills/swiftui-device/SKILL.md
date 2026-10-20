---
name: swiftui-device
description: Reach a real iOS 6 device for SwiftUI work — claim it, copy files over and back, install the demo and take device snapshots, and read its crash reports with frameworks/SwiftUI/tools/device.lua, and read "Permission denied" or connection-reset failures correctly. Use whenever SwiftUI work needs hardware (not the emulator). The fleet discipline itself (claim, launch, tap, respring, privacy, cleanup) is the workspace skill `device-session`.
---

# Device access from SwiftUI

The procedure for any device session — claiming, launching, touching, respring, privacy,
cleanup — is the workspace skill `device-session`: read
`$HOME/Git/projects/ios/.agents/skills/device-session/SKILL.md` first. This file only adds what
is specific to SwiftUI.

## Claim

`xmake device` and `device.lua` both read the phone from a `device.env` (or `device.NAME.env`) in
the folder they run in; it is git-ignored and never committed. Run both from the top of the
revenant checkout, with a `device.env` there:

```
export REVENANT_DEVICE_HOLDER=<task>
./xmakew device list
./xmakew device --minutes=30 claim          # -d NAME (or REVENANT_DEVICE=NAME) picks device.NAME.env
```

A claim without a holder errors, and every action of `device.lua` refuses a phone that
`REVENANT_DEVICE_HOLDER` has not claimed, so keep it exported for the whole session. Running a
command on the phone and reading its log are `./xmakew device run` and `./xmakew device log`.

## device.lua

```
./xmakew l frameworks/SwiftUI/tools/device.lua copy LOCAL REMOTE
./xmakew l frameworks/SwiftUI/tools/device.lua fetch REMOTE LOCAL
./xmakew l frameworks/SwiftUI/tools/device.lua shots [--live | --gesture] SCENARIO...
./xmakew l frameworks/SwiftUI/tools/device.lua crash [REPORT.plist]
```

`shots` installs the built `SwiftUIDemo.app` (`./xmakew build -P . SwiftUIDemo` first) into
`/Applications`, launches it through SpringBoard with `/private/var/tmp/sblaunch`, and for each
scenario fetches what the app rendered in its own process (`--live`: a picture of the real screen;
`--gesture`: the screen when the scenario's touches have opened the row, and after them). The
pictures go to `$HOME/.revenant/cache/<task>/swiftui/device-shots/`.

`crash` fetches the demo's `LatestCrash-SwiftUIDemo.plist` from the phone (or reads REPORT) and
symbolicates its app frames against the built demo; `frameworks/SwiftUI/tools/crash.lua` does the
reading.

## Traps

- "Permission denied (publickey,password,...)" from a raw `ssh`/`scp` to a guessed port means the wrong device, not the wrong password: `pgrep -fl iproxy` shows which UDID each tunnel serves.
- `kex_exchange_identification: Connection reset` is the USB tunnel or dropbear rate-limiting: slow down and retry; it is not a crash.
- `launchctl list | grep com.apple.SpringBoard` is the liveness check; the device's `ps ax | grep` is not reliable.
- `/usr/bin/shot` always writes `/tmp/screenshot.png`, whatever path it is given.
- No UDID, address, hostname or password in a tracked file, commit or skill; `alpine`, the public jailbreak default, is the only credential that may be named.
