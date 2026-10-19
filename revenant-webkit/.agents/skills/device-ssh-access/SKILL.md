---
name: device-ssh-access
description: Reach a jailbroken legacy-iOS device from this repo — claim it with `xmake device`, then run a command, copy or fetch a file with `charon device`, tell whether it is actually alive, and read a "Permission denied" or connection-reset failure correctly instead of assuming the credentials are wrong. Use whenever a task needs to touch a real device (not the shade emulator).
---

# Device access

In this repo the transport is the Conan `charon device` verb
(`charon/config/extensions/charon/device.py`) — never hand-rolled `ssh`/`scp` to a guessed
host/port. It does **not** check claims and does **not** check which device a tunnel serves, so
claim through charon's `xmake device` first.

## Claim, work, release

The fleet rule: claim before any device use; a failed claim (`... is held by X until HH:MM`) is a
stop — wait, never override. `xmake device` works in any directory holding `device*.env` (no
`xmake.lua` needed), so run it from this repo's root:

```
export CHARON_DEVICE_HOLDER=<name>
xmake device list                      # attached devices, their tunnels, current holders
xmake device --minutes=30 claim        # -d ipad2 or CHARON_DEVICE=ipad2 picks device.ipad2.env
charon device run <seconds> "<command>"
charon device copy <local> <remote>
charon device fetch <remote> <local>
charon device where                    # host:port the env file names
charon device log [seconds] [text]     # idevicesyslog, filtered
xmake device release
```

- `CHARON_DEVICE=ipad2` (or `charon --device ipad2 ...`) makes `charon device`, `charon install`,
  `charon deploy` and `charon test` read `device.ipad2.env` too; keep it set for the whole session.
- A claim over a USB tunnel needs `DEVICE_UDID` in the env file; `xmake device list` shows it.
- `device.env` is gitignored, so a new worktree has none: copy the main checkout's, never commit it.
- `nothing names a phone`: the env file the command picked does not exist in this directory.

Each `charon device` command reads the env file (`DEVICE_UDID` / `DEVICE_HOST` / `DEVICE_PORT` /
`DEVICE_PASSWORD`, else the environment) and, when a `127.0.0.1` port is closed, restarts
`iproxy <port> 22 -u <DEVICE_UDID>` before running, so a dead tunnel reads as "connection refused"
rather than a hang. The well-known default password on a freshly jailbroken device is `alpine`;
nothing more specific than that belongs in a tracked file, a commit, or this skill.

## "Permission denied (publickey,password,...)" almost never means the password is wrong

It means the command reached the wrong device. On a host running a USB tunnel (`iproxy`), a port
number by itself reaches whichever device that tunnel currently serves. `xmake device run` checks
this and raises `port %s tunnels to %s, not to %s`; `charon device` has no such check (it only
restarts a tunnel that is down), so a live tunnel to the other phone fails at the credential stage
and reads exactly like a wrong password.

- Find what's actually bound: `pgrep -fl iproxy` (lines look like `iproxy <port> 22 -u <udid>`).
- Or `xmake device list` — every attached device with its tunnel port and holder.
- Never guess a port. On a host with more than one attached device, a guessed port reaches
  whichever phone that tunnel happens to serve today.

## The device looks dead

- Liveness: `launchctl list | grep com.apple.SpringBoard` or `killall -0 <process>`. The device
  has no `ps`, `head`, `tail`, `wc`, `uptime`, `nohup` or `timeout`; trim output on the host
  (`charon device run 12 "..." | tail`).
- A screenshot (`/usr/bin/shot`, always writes to `/tmp/screenshot.png` regardless of any path
  argument) confirms whether the UI is actually up.
- `kex_exchange_identification: read: Connection reset by peer` while the tunnel is still
  listening is usually the USB tunnel glitching, or dropbear rate-limiting rapid reconnects —
  slow down and retry, or re-seat USB. It is usually not a device crash.

## Privacy

Never write a real device UDID, IP/hostname, or password into a tracked file, a commit message,
or a skill — `alpine` (the well-known jailbreak default) is the only credential-shaped string
that's safe to name. Everything device-specific lives in the gitignored `device.env`.
