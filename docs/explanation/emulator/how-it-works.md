# How the emulator works

## What it does

- Emulates the devices in `emulator profile --list`: iPhone 2G, 3G, 3GS, 4 and 4S, iPod touch 1, 2 and 4, iPad and
  iPad 2.
- Boots real firmware root filesystems from iPhone OS 3.0 through iOS 6.1.3 in Revenant's acceptance runs; the kernel
  ABIs it knows are listed by `emulator abi`.
- Draws the guest's OpenGL ES on a host Vulkan driver, plays its audio, delivers touch and button input, and answers
  the guest's IOKit, Mach and BSD calls itself.
- Publishes the hardware the firmware looks for (audio, baseband, display, keybag) the way the real devices do. The
  iPhone 4S's Voice audio device is described from a registry dump of a real one.
- Runs a test program inside the guest and hands back its result. That is how the toolchain's `./xmakew emulate`
  uses it.

## How it works

`emulator boot` loads the root filesystem and starts `launchd` as the guest's first process. The guest's CPU is
translated to host code by Dynarmic. Its system calls, Mach messages and IOKit requests are answered by the
emulator's own kernel model in `src/kernel`, `src/mach` and `src/device_state`. The frameworks the emulated hardware
would serve (graphics, audio, telephony) are answered where they cross the boundary, in `src/graphics`, `src/media`
and `src/telephony`.

The emulator emulates an XNU kernel and the devices the firmware asks about. It does not emulate hardware registers,
so the firmware's own launchd, daemons and frameworks run unchanged on top.

Persistent translations are keyed on the Dynarmic package's build fingerprint, so an artifact made by another core
is never reused.

## Layout

- `src/app/`: the verbs, the live control channel (`--control-stdin`), the SDL window; its headers are in `include/app/`.
- `src/runtime/`: the session, the boot options, the scheduler loop, the pacer.
- `src/kernel/`: the BSD and Mach side of the kernel; `src/mach/` Mach messaging and the execution policies;
  `src/device_state/` what the firmware is told about the device (identity, kernel configuration, activation).
- `src/foundation/`: the address space, the CPU wrapper around Dynarmic, the file page cache and the host file watcher.
- `src/graphics/`, `src/media/`, `src/network/`, `src/telephony/`, `src/bluetooth/`, `src/storage/`, `src/crypto/`:
  the devices and frameworks the guest talks to; `src/host/` is what they use on the Mac.
- `src/debug/`: the gdb remote stub (`--gdb PORT`): registers, memory, software breakpoints, all processes as
  `pPID.TID`.
- `tests/guest/dns-probe/`: the guest-side DNS probe, built only with a root filesystem and an ARMv6 linker.
- `src/glsl/`: the host tool that compiles the Vulkan shaders to the word lists the renderer includes.
