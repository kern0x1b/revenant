# 0014: Performance is a requirement

Status: accepted

## Context

The platform runs today's apps on the iPhone 4S and the iPad 2: an Apple A5, two Cortex-A9 cores at 800 MHz or
1 GHz, NEON, 512 MB of memory, iOS 6.1.3. Apple tunes each release's code for the hardware that release supports,
and nothing of iOS 7 or later was ever tuned for the A5. An app that starts but stutters, drains the battery or is
killed for memory has not been brought to the device. Every layer we add (a backport, a shim, a lowered overlay, a
runtime) runs on the A5 in place of code that ran natively on a newer device.

## Decision

Speed and memory are part of correctness for everything this repository writes or generates.

- Code we write is efficient by design: the right algorithm and data layout first, then no needless allocation,
  copying, locking, dynamic dispatch or system calls on a hot path. Where Apple's own implementation is known (its
  open source, or the release measured), ours aims to be at least as fast on the A5, and faster where Apple's was
  tuned for other hardware.
- A claim about speed is a measurement. The iPhone 4S or iPad 2 is the truth; the emulator gives instruction and
  call counts, which compare two versions of the same code and are never reported as times. Host timings compare
  only versions of the same code on the same host.
- Build settings for the device are chosen by measurement on the A5 (CPU tuning, optimisation level, LTO,
  dead-stripping, Swift's optimisation mode) and are not inherited from a default made for other hardware.
- The compiler is ours to improve. An optimisation the A5 needs and LLVM or Swift lacks is a patch on the `llvm` or
  `swift` package, upstreamable and tested like any other patch.
- Memory counts as speed: a working set that pushes an app out of 512 MB is a performance defect. Backports answer
  memory warnings by giving back what can be made again, as iOS does.
- The bar is an app that runs well, not one that starts: smooth scrolling and animation, no stalls on the main
  thread, no crashes, inside the memory the device has, and looking as its authors designed it.
- The app's own source is never touched. The levers are the Backports libraries and runtimes the app links, and the
  toolchain that builds it: its compiler, its optimisation settings and the link of the app with our libraries.

## Consequences

- A change on a hot path (object allocation, messaging, the run loop, layout, drawing, text, I/O, the `*at` shims,
  Swift runtime entry points) comes with a before and after measurement.
- Reused open-source code is measured as our own is; reuse does not exempt it.
- A slower but simpler implementation is accepted only with the measurement that shows it is off the hot path.

## Enforced by

Not enforced. A benchmark group under `./xmakew test`, with recorded baselines that a regression fails, is the check
this record needs.
