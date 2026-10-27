---
name: device-session
description: Use when a task has to run on a real jailbroken legacy iPhone or iPad (iOS 6) instead of the emulator: claim the phone, run a command on it, copy files to or from it, read its log, take a screenshot, or fetch SwiftUI demo snapshots and crash reports from it.
---

# Real device

Run everything from the top of the checkout with `./xmakew`. The phone's address lives in `device.env`, or `device.NAME.env` when several phones are attached; git ignores both. `frameworks/WebKit/tests/data/device.env.example` is the template. A new worktree has none: copy the main checkout's, never commit one.

The module reads these from the env file or the environment: `DEVICE_HOST`, `DEVICE_PORT`, `DEVICE_UDID` (needed for a USB tunnel and for claiming), `DEVICE_PASSWORD` (leave it unset to use an SSH key). `nothing names a phone` means the env file the command picked does not exist here.

## Claim

Every device action refuses a phone that another holder has claimed, so claim first.

- `export REVENANT_DEVICE_HOLDER=<your name>` for the whole shell.
- `./xmakew device list`: attached devices, their UDID, tunnel port and claim.
- `./xmakew device --minutes=30 claim`: lasts 30 minutes unless released or claimed again by the same name. `-d NAME` (or `REVENANT_DEVICE=NAME`) picks `device.NAME.env`.
- `./xmakew device release`.

A claim held by another name fails until it is released or expires.

## Run, log, install

- `./xmakew device run "<command>"`: runs as root over ssh. `-s SECONDS` raises the limit.
- `./xmakew device log [TEXT]`: `idevicesyslog` for `-s` seconds (default 15), filtered to TEXT.
- `./xmakew device where`: the host:port the env file names.
- `./xmakew device install`: builds the package and runs `dpkg -i` on the phone (see the `webkit` skill).
- A closed `127.0.0.1` tunnel port is restarted with `iproxy` for `DEVICE_UDID` before a command runs.

## Copy files

- `scp -P <DEVICE_PORT> LOCAL root@<DEVICE_HOST>:REMOTE`, or the other way round.
- Through the module, with the same claim and tunnel: `./xmakew l frameworks/SwiftUI/tools/device.lua copy LOCAL REMOTE` and `fetch REMOTE LOCAL`.

Local files go under `.cache/scratch/<task>/`, not into the checkout.

## Snapshots

- The screen: `./xmakew device run 'sleep 8; /usr/libexec/revenant-shot /tmp/screenshot.png'`, then fetch `/tmp/screenshot.png`. `revenant-shot PATH` writes the PNG to PATH; the tool provisions it with the launcher. A page that loads slowly needs 15 to 30 s before the shot.
- SwiftUI demo: `./xmakew build SwiftUIDemo` first, then `./xmakew l frameworks/SwiftUI/tools/device.lua shots [--live | --gesture] SCENARIO...`. It builds the guest tools `revenant-sblaunch`, `revenant-shot` and `revenant-unlock` (the guest targets of the SwiftUIDemo component, rebuilt when the guest sources, the shared `showcase/device/hid.*`, the daemon rule or the SDK change), installs them signed (`xmake install`; SpringBoard refuses a launch from an unsigned caller, so the build output is never provisioned), copies each to `/usr/libexec` when its SHA-256 differs, creates `/var/revenant`, installs the demo into `/Applications`, then for each scenario unlocks the phone (`revenant-unlock`: wakes the screen and slides the lock screen away when it has no passcode; a passcode lock stops the run; the slide is measured per phone family in points, iPad 2 at 768x1024 with the knob 287 points from the left and 64 above the bottom and the track end at 553, iPhone4,1 (4S) at 320x480 with the knob at 52.5 and 48.5 and the track end at 240, then scaled to the size `revenant-unlock screen` reports), launches the demo through the launcher and takes each picture with `revenant-shot`: `--live` the real screen, `--gesture` the screen after the scenario's touches. Auto-lock is not changed. Pictures go to `.cache/scratch/<task>/swiftui/device-shots/`.
- Launcher check: `./xmakew device run '/usr/libexec/revenant-sblaunch --probe'` prints the uid, the SpringBoard ports and the launch error table without launching anything.
- The demo links revenant's backports from `/usr/lib/revenant/org.revenant.backports`, which only the platform package `org.revenant.backports` installs. A phone without it accepts the launch ("launched 0.0 s") and dyld ends the demo before it logs anything. The tool checks each such library before a run (`otool -L` on the built app, `test -f` on the phone) and launches with `--stdout`/`--stderr`, so a demo that does not start fails with its stderr. `dpkg -l | grep revenant` on the phone shows whether the package is there.
- The live pictures depend on the phone's own settings. The launch passes the emulator's locale and time zone (`-AppleLanguages (en) -AppleLocale en_US` and `TZ=America/Los_Angeles`, the iOS factory default inferred from the reference's 12:00 AM), but not the keyboard. The `suggestions` baseline shows the Russian keyboard because the phone has it enabled; a phone without that keyboard changes the picture, so re-accept the baseline there rather than comparing it with this one.
- The iPad 2 tree check has a limit: the committed trees come from the iPod touch, and no iPad 2 emulator tree exists yet (its configure hangs, see the oracle note). Of the iPad's 38 trees, 30 match the committed ones once frames are removed, and their frames differ. Unclassified: the 4 content differences (`app-detail`, `app-empty`, `app-settings`, `pickers`) and the large frame deltas (up to 890 pt in `app-dashboard`).
- Crash report: `./xmakew l frameworks/SwiftUI/tools/device.lua crash [REPORT.plist]` fetches `LatestCrash-SwiftUIDemo.plist` (or reads REPORT) and symbolicates it against the built demo.

## Is it alive?

- `./xmakew device run 'launchctl list | grep com.apple.SpringBoard'`: a line means SpringBoard runs. The same pid on two checks means it is not crash-looping.
- The phone has no `ps`, `head`, `tail`, `wc`, `uptime`, `nohup` or `timeout`. Trim output on the host: `./xmakew device run "..." | tail`.
- A screenshot shows whether the UI is up.
- `kex_exchange_identification: Connection reset` while the tunnel listens is the USB tunnel or dropbear rate-limiting fast reconnects. Slow down, retry or reseat the USB cable. It is not a crash.

## "Permission denied" usually means the wrong phone

A port on a host with a USB tunnel reaches whichever phone that tunnel serves right now. `device run` raises `port P tunnels to X, not to Y` when `DEVICE_UDID` is set. Without it nothing catches the mismatch, and it reads as a wrong password. Find the binding with `pgrep -fl iproxy` (lines read `iproxy <port> 22 -u <udid>`) or `./xmakew device list`. Never guess a port.

## Privacy

Never write a UDID, address, hostname or password into a tracked file, a commit message or a skill. `device.env` is the only place for them.
