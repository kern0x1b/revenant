---
name: device
description: Use when a task has to run on a real jailbroken legacy iPhone or iPad (iOS 6) instead of the emulator: claim the phone, run a command on it, copy files to or from it, read its log, take a screenshot, or fetch SwiftUI demo snapshots and crash reports from it.
---

# Real device

Run everything from the top of the checkout with `./xmakew`. The phone's address lives in `device.env`, or `device.NAME.env` when several phones are attached; git ignores both. `frameworks/WebKit/device.env.example` is the template. A new worktree has none: copy the main checkout's, never commit one.

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
- From Lua, through the same claim and tunnel: `./xmakew l frameworks/SwiftUI/tools/device.lua copy LOCAL REMOTE` and `fetch REMOTE LOCAL`.

Local files go under `$HOME/.revenant/cache/<task>/`, not into the checkout.

## Snapshots

- The screen: `./xmakew device run 'sleep 8; /usr/bin/shot >/dev/null 2>&1'`, then `scp` `/tmp/screenshot.png`. `shot` always writes `/tmp/screenshot.png`, whatever path it is given. Heavy pages need 15 to 30 s to finish loading.
- SwiftUI demo: `./xmakew build SwiftUIDemo` first, then `./xmakew l frameworks/SwiftUI/tools/device.lua shots [--live | --gesture] SCENARIO...`. It installs the demo into `/Applications`, launches it through `/private/var/tmp/sblaunch`, and fetches each scenario's picture: `--live` the real screen, `--gesture` the screen after the scenario's touches. Pictures go to `$HOME/.revenant/cache/<task>/swiftui/device-shots/`.
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
