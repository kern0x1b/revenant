# Contributor guide

Working notes for whoever is changing Shade, human or AI.

## What this is

An emulator that boots a legacy iOS firmware's own userland. It does not emulate
hardware registers: it emulates an XNU kernel (system calls, Mach, IOKit) and the
devices the firmware asks about, and lets the firmware's real launchd, daemons and
frameworks run on top, on a JIT-translated ARM CPU (`external/umbra`).

## Build and run

The program is `build/shade`; the skill `shade-boot` (`.agents/skills/shade-boot/SKILL.md`)
builds it, boots a root filesystem and reads the log.

Workspace-wide procedures are skills in `$HOME/Git/projects/ios/.agents/skills/`: `device-session` (claim, run, install, launch, tap on a real device), `canon-install`, `patch-merge`, `worktree-sweep`, `session-handoff`, `band-launch`, `band-supervise`. A session started inside this repository does not list them — read `<name>/SKILL.md` there.

## Layout

- `app/` the verbs, the live control channel (`--control-stdin`), the SDL window.
- `src/runtime/` the session: boot options, the scheduler loop, the pacer.
- `src/kernel/` the BSD and Mach side of the kernel; `src/mach/` Mach messaging
  and the execution policies; `src/device_state/` what the firmware is told about
  the device (identity, kernel configuration, activation).
- `src/foundation/` the address space, the CPU wrapper around Umbra, file page
  cache and host file watcher.
- `src/graphics/`, `src/media/`, `src/network/`, `src/telephony/`,
  `src/bluetooth/`, `src/storage/`, `src/crypto/` the devices and frameworks the
  guest talks to; `src/host/` is what they use on the Mac.
- `src/debug/` the gdb remote stub (`--gdb PORT`): registers, memory, software
  breakpoints, all processes as `pPID.TID`.
- `external/` see `THIRD-PARTY.md`; do not edit the vendored trees.

## Things that bite

- **A guest second is slower than a device's.** Without `--time-scale 10` the
  guest's own watchdogs and RPC deadlines expire before it finishes: iOS 6.1.3 loses
  SpringBoard every 100 s to a mediaserverd timeout.
- **Firmware jobs come from a cache on iOS 6.1.** launchd stats only the
  LaunchDaemons plists that the cache inside the dyld shared cache lists, so a
  plist added to that folder is never started. `/etc/launchd.conf` is still read,
  and its `bsexec` line starts a program - but launchctl waits for it, so a program
  that stays has to leave launchctl behind (fork, parent exits).
- **An audio device the firmware needs must be described completely.** iOS 6.1.3's
  audio plug-in opens a route only after finding the Voice device's input stream;
  without one it throws with its state lock held and mediaserverd deadlocks.
  Describe devices from a registry dump of a real one, never from a guess.
- **A fault ends the process.** A CPU fault - a bad access, a non-executable page -
  ends the guest process; no Mach exception and no signal is raised yet.
- **Names the emulator writes.** `.shade-device-state` (the device state next to a
  run), `.shade-cache`, `shade-shared-cache-<uid>` in the temporary directory, and
  the label the device's class keys are derived under in `src/crypto/host`; changing
  the last invalidates every saved device state.
- **Logs are the interface.** Charon reads the emulator's log lines
  (`[process] spawn-setexec`, `[cpu] fatal`, `[display] frame=`); do not reword them
  without changing its reader.

## Conventions

- Every source file starts with the MPL-2.0 notice; keep it on a file you change or
  add.
- Commits: plain imperative subject, a body that says why, and the
  writing agent's own `Co-Authored-By:` trailer.
- No personal data in tracked files: no device addresses, host names or absolute
  paths.
- Version numbers are Shade's own, from `v0.1.0`; `CHANGELOG.md` records every
  release.
