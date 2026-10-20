---
name: revenant-device
description: Reach a jailbroken legacy-iOS device from this repo — claim it with `xmake device`, then run a command with it and copy or fetch a file through the device module, tell whether it is actually alive, and read a "Permission denied" or connection-reset failure correctly instead of assuming the credentials are wrong. Use whenever a task needs to touch a real device (not the emulator).
---

# Device access

In this repo the transport is the toolchain's device module (`toolchain/modules/device.lua`),
reached as `./xmakew device` from a shell and imported by Lua scripts such as the WebKit port's
tests — never hand-rolled `ssh`/`scp` to a guessed host/port. `./xmakew device` checks claims and
which device a tunnel serves; a script that imports the module checks the tunnel but not the
claim, so claim first.

## Claim, work, release

The fleet rule: claim before any device use; a failed claim (`... is held by X until HH:MM`) is a
stop — wait, never override. `xmake device` works in any directory holding `device*.env` (no
`xmake.lua` needed), so run it from this repo's root:

```
export REVENANT_DEVICE_HOLDER=<name>
xmake device list                      # attached devices, their tunnels, current holders
xmake device --minutes=30 claim        # -d ipad2 or REVENANT_DEVICE=ipad2 picks device.ipad2.env
xmake device [-s seconds] run "<command>"
xmake device where                     # host:port the env file names
xmake device [-s seconds] log [text]   # idevicesyslog, filtered
xmake device release
```

Copying a file is the module's `copy` and `fetch` from Lua, or `scp -P <DEVICE_PORT>` to the
host the env file names.

- `REVENANT_DEVICE=ipad2` (or `-d ipad2`) makes `xmake device` and every script that binds the
  device module read `device.ipad2.env`; keep it set for the whole session.
- A claim over a USB tunnel needs `DEVICE_UDID` in the env file; `xmake device list` shows it.
- `device.env` is gitignored, so a new worktree has none: copy the main checkout's, never commit it.
- `nothing names a phone`: the env file the command picked does not exist in this directory.

Each device command reads the env file (`DEVICE_UDID` / `DEVICE_HOST` / `DEVICE_PORT` /
`DEVICE_PASSWORD`, else the environment) and, when a `127.0.0.1` port is closed, restarts
`iproxy <port> 22 -u <DEVICE_UDID>` before running, so a dead tunnel reads as "connection refused"
rather than a hang. The well-known default password on a freshly jailbroken device is `alpine`;
nothing more specific than that belongs in a tracked file, a commit, or this skill.

## "Permission denied (publickey,password,...)" almost never means the password is wrong

It means the command reached the wrong device. On a host running a USB tunnel (`iproxy`), a port
number by itself reaches whichever device that tunnel currently serves. `xmake device run` checks
this and raises `port %s tunnels to %s, not to %s` when `DEVICE_UDID` is set; without it there
is nothing to check against, so a live tunnel to the other phone fails at the credential stage
and reads exactly like a wrong password.

- Find what's actually bound: `pgrep -fl iproxy` (lines look like `iproxy <port> 22 -u <udid>`).
- Or `xmake device list` — every attached device with its tunnel port and holder.
- Never guess a port. On a host with more than one attached device, a guessed port reaches
  whichever phone that tunnel happens to serve today.

## The device looks dead

- Liveness: `launchctl list | grep com.apple.SpringBoard` or `killall -0 <process>`. The device
  has no `ps`, `head`, `tail`, `wc`, `uptime`, `nohup` or `timeout`; trim output on the host
  (`xmake device run "..." | tail`).
- A screenshot (`/usr/bin/shot`, always writes to `/tmp/screenshot.png` regardless of any path
  argument) confirms whether the UI is actually up.
- `kex_exchange_identification: read: Connection reset by peer` while the tunnel is still
  listening is usually the USB tunnel glitching, or dropbear rate-limiting rapid reconnects —
  slow down and retry, or re-seat USB. It is usually not a device crash.

## Privacy

Never write a real device UDID, IP/hostname, or password into a tracked file, a commit message,
or a skill — `alpine` (the well-known jailbreak default) is the only credential-shaped string
that's safe to name. Everything device-specific lives in the gitignored `device.env`.
