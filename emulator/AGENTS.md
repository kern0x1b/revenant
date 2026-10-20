# Contributor guide

Working notes for whoever is changing the emulator, human or AI.

## What this is

An emulator that boots a legacy iOS firmware's own userland. It does not emulate
hardware registers: it emulates an XNU kernel (system calls, Mach, IOKit) and the
devices the firmware asks about, and lets the firmware's real launchd, daemons and
frameworks run on top, on a JIT-translated ARM CPU (Dynarmic: revenant's `dynarmic` package, an upstream
commit with our patches, in `third_party/dynarmic`).

## Build and run

The emulator builds with xmake from the top of revenant: `xmake f -y`, `xmake build emulator`, `xmake test`. Each
module folder has an `xmake.lua` with its libraries; `emulator/xmake.lua` holds the options, the packages
and the two rules every target uses (`emulator.module`: C++20, the warnings, the module's `include/` as its
public include root, LTO in release; `emulator.glsl`: the Vulkan shaders through `emulator_glsl_to_spirv`, the host tool in `tools/glsl` on the glslang
library, which writes each shader as the C word list the renderer includes; it is a build fence, so the renderer's
shaders wait for it). The program is
`build/macosx/arm64/release/emulator`, with SwiftShader's `libvk_swiftshader.dylib` (Revenant's `swiftshader`
package) copied beside it: the Vulkan renderer loads that file by path through the loader, and without a
usable driver a boot falls back to the reference renderer with one log line. The skill `emulator-boot` (revenant's `.agents/skills/emulator-boot/SKILL.md`)
builds it, boots a root filesystem and reads the log.

The kernel's libraries share `emulator_kernel_api`, a target with no sources that carries the kernel's
include root and the modules its headers name, so a kernel library gets the contract without linking
back to `emulator_kernel`. `emulator_graphics` writes `boot_placeholder.hpp` (the PNG in `assets/` as a byte
array) when it is configured, and only when the content changed. The guest probe in `tools/guest` is a
target only when `--emulator_guest_rootfs` and `--emulator_armv6_ld` are given: it needs the cctools-port
ARMv6 linker (`tools/bootstrap_armv6_ld.sh`) and a root filesystem to link against;
`xmake build emulator_install_guest_dns_probe` puts it and its launchd job into that root filesystem.
Persistent IR artifacts are keyed on `DYNARMIC_BUILD_FINGERPRINT`, which the dynarmic package defines
from its commit and its patches' checksums.

## Layout

- `app/` the verbs, the live control channel (`--control-stdin`), the SDL window.
- `src/runtime/` the session: boot options, the scheduler loop, the pacer.
- `src/kernel/` the BSD and Mach side of the kernel; `src/mach/` Mach messaging
  and the execution policies; `src/device_state/` what the firmware is told about
  the device (identity, kernel configuration, activation).
- `src/foundation/` the address space, the CPU wrapper around Dynarmic, file page
  cache and host file watcher.
- `src/graphics/`, `src/media/`, `src/network/`, `src/telephony/`,
  `src/bluetooth/`, `src/storage/`, `src/crypto/` the devices and frameworks the
  guest talks to; `src/host/` is what they use on the Mac.
- `src/debug/` the gdb remote stub (`--gdb PORT`): registers, memory, software
  breakpoints, all processes as `pPID.TID`.
- Nothing third-party is vendored (`THIRD-PARTY.md`): a change to Dynarmic is a new patch in
  `third_party/dynarmic/patches/`, listed in that recipe.

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
- **Names the emulator writes.** `.emulator-device-state` (the device state next to a
  run), `.emulator-cache`, `emulator-shared-cache-<uid>` in the temporary directory, and
  the label the device's class keys are derived under in `src/crypto/host`; changing
  the last invalidates every saved device state.
- **Logs are the interface.** The toolchain reads the emulator's log lines
  (`[process] spawn-setexec`, `[cpu] fatal`, `[display] frame=`); do not reword them
  without changing its reader.

## Conventions

- Every source file starts with the MPL-2.0 notice; keep it on a file you change or
  add.
- Commits: plain imperative subject, a body that says why, and the
  writing agent's own `Co-Authored-By:` trailer.
- No personal data in tracked files: no device addresses, host names or absolute
  paths.
- Version numbers are the emulator's own, from `v0.1.0`; `CHANGELOG.md` records every
  release.
