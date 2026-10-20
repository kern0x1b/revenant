# Contributor guide: the emulator

For whoever is changing the emulator, human or AI. The repository-wide rules are in the root `AGENTS.md`.

## What this is

An emulator that boots a legacy iOS firmware's own userland. It does not emulate hardware registers: it emulates an
XNU kernel (system calls, Mach, IOKit) and the devices the firmware asks about, and lets the firmware's real launchd,
daemons and frameworks run on top, on a JIT-translated ARM CPU (Dynarmic: revenant's `dynarmic` package, an upstream
commit with our patches, in `third_party/dynarmic`).

[How it works](../../explanation/emulator/how-it-works.md) describes the pieces. [Build and test](build-and-test.md)
covers the build, the options and a boot.

## Layout

- `src/app/`: the verbs, the live control channel (`--control-stdin`), the SDL window; its headers are in `include/app/`.
- `src/`: the library. `src/runtime/` is the session, `src/kernel/` the BSD and Mach side of the kernel,
  `src/mach/` Mach messaging, `src/device_state/` what the firmware is told about the device, `src/foundation/` the
  address space and the CPU wrapper, and `src/graphics/`, `src/media/`, `src/network/`, `src/telephony/`,
  `src/bluetooth/`, `src/storage/`, `src/crypto/` the devices and frameworks the guest talks to, with `src/host/`
  for what they use on the Mac.
- `tools/`: the guest probe (`tools/guest`) and the GLSL shader compiler (`tools/glsl`).
- Nothing third-party is vendored ([the third-party notices](../../reference/emulator/third-party.md)). A change to
  Dynarmic is a new patch in `third_party/dynarmic/patches/`, listed in that package.

## Things that bite

- **A guest second is slower than a device's.** Without `--time-scale 10` the guest's own watchdogs and RPC
  deadlines expire before it finishes. iOS 6.1.3 loses SpringBoard every 100 s to a mediaserverd timeout.
- **Firmware jobs come from a cache on iOS 6.1.** launchd stats only the LaunchDaemons plists that the cache inside
  the dyld shared cache lists, so a plist added to that folder is never started. `/etc/launchd.conf` is still read,
  and its `bsexec` line starts a program. launchctl waits for that program, so a program that stays has to leave
  launchctl behind (fork, and the parent exits).
- **An audio device the firmware needs must be described completely.** iOS 6.1.3's audio plug-in opens a route only
  after finding the Voice device's input stream; without one it throws with its state lock held and mediaserverd
  deadlocks. Describe devices from a registry dump of a real one, never from a guess.
- **A range invalidation must reach every block it covers.** Dynarmic's `equal_range` over a Boost interval map
  stops at the first of several overlapping blocks. The patch in `third_party/dynarmic` walks the map from the
  range's start instead. Any new lookup over overlapping intervals needs the same care.
- **A fault ends the process.** A CPU fault (a bad access, a non-executable page) ends the guest process; no Mach
  exception and no signal is raised yet.
- **Names the emulator writes.** `.emulator-device-state` (the device state next to a run), `.emulator-cache`,
  `emulator-shared-cache-<uid>` in the temporary directory, and the label the device's class keys are derived under
  in `src/crypto/host`. Changing the last invalidates every saved device state.
- **Logs are the interface.** The toolchain reads the emulator's log lines (`[process] spawn-setexec`, `[cpu] fatal`,
  `[display] frame=`). Do not reword them without changing its reader.

## Conventions

- Every source file starts with the MPL-2.0 notice; keep it on a file you change or add.
- Commits: a plain imperative subject, and a body that says why, with the writing agent's own `Co-Authored-By:`
  trailer.
- No personal data in tracked files: no device addresses, host names or absolute paths.
- Version numbers are the emulator's own, from `v0.1.0`. [The changelog](../../reference/emulator/changelog.md)
  records every release.
