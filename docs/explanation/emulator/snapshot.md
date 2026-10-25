# Snapshot and restore of a booted emulator

A test or a Telegram run boots a firmware from its root filesystem before it does anything, and a boot to SpringBoard
takes most of a minute on an idle Mac and longer under load. The emulator has no machine snapshot: `grep` finds none,
and the control channel's `snapshot PATH` writes one display frame (`src/runtime/emulator_session.cpp:2912-2922`).
This page says what a snapshot would have to hold, what it cannot hold, what a booted machine weighs, and what a
restore would cost. It is a design from measurements, not an implementation.

Paths are relative to `emulator/`. Entries marked † come from a read-only survey of the source and were not re-read one
by one; every other entry was read at the line given.

## What was measured

The Mac has 12 cores and 24 GiB. Its load average was 30 to 37 during both runs, from other workers' boots and builds, so
the times below are not idle-machine times. The binary is a release build of `main` at `1ae465470`. The rootfs is
iPhone4,1 on 6.1.3 (10B329): an APFS clone of the pristine firmware in `~/.revenant/firmware`, booted fresh with an
empty host cache, from a rootfs that had never booted.

| run | `--time-scale` | SpringBoard spawned (`spawn-setexec`, emulator host clock from launch) | sampled at | physical footprint | written (dirty + swapped) | dirty | display |
|---|---|---|---|---|---|---|---|
| 1 | 1 (default) | 112 s | 900 s after launch | 3.7 GB | 3.7 GB (dirty 0.49 GB, swapped 3.2 GB) | 0.49 GB | boot logo with its progress bar; Mach requests stalled at guest 239 s (`fseventsd`) and 853 s (`syslogd`) |
| 2 | 10 | 84 s | 30 s after the spawn | 2.5 GB | 2.5 GB (dirty 0.11 GB, swapped 2.4 GB) | 0.11 GB | boot logo (frame 1 only) |

Neither run reached a drawn SpringBoard, so neither measures a snapshot at "SpringBoard ready". There are two reasons.

- The emulator's own ready signal is `did-finish-launching pid=N SpringBoard` in `/private/var/revenant/events.log`,
  written by `revenant-inject.dylib`. A plain boot's rootfs has no `/private/var/revenant` at all, so that signal is
  unavailable outside the test harness. The only SpringBoard signal a plain boot logs is the spawn line.
- Both runs stayed on the logo. Checked right after run 1 ended, the host had 33,000 free pages of 1.57 million, so it
  had been swapping, and run 1's guest stalled on Mach requests. Run 2 was sampled too early to tell whether it would
  have finished.

The 58 to 71 s figure in the task brief was not reproduced: run 2 spawned SpringBoard at 84 s and run 1 at 112 s, under
load and with different time scales. Stage 0 below defines the ready point before any number is compared.

### Where the memory is, at 30 s after the spawn (run 2)

`vmmap -summary` splits the process's memory by region type. Under pressure the host compresses or swaps most
written memory, so resident size is not the snapshot's size: "written" (dirty plus swapped) is.

| region group | written | resident | what it is |
|---|---|---|---|
| malloc small and large, incl. the empty zones | about 2.2 GB (dirty 0.09 GB) | about 0.1 GB | guest page backings (each a 4 KiB byte array plus bookkeeping, `src/foundation/include/foundation/file_page_cache.hpp:34,229`) and host structures; not separable without instrumentation |
| `Untagged` | 0.37 GB | 19 MB dirty | host, most likely the JIT reservation (`jit-shared-reserved=6442450944` in the boot's counters); excluded from a snapshot |
| `__TEXT` and other read-only libraries | 0 written | 445 MB | clean, file-backed from the rootfs and the shared cache |
| `mapped file` | 0 written | 85 MB | clean, file-backed |

Totals: 2.5 GB written, 0.11 GB dirty, 0.45 GB of clean file-backed library pages that a snapshot does not need to
save. Run 1 at 900 s had 3.7 GB written (0.49 GB dirty), so memory keeps growing after SpringBoard spawns. The
guest's 54 process spawns before SpringBoard (run 2) include those that exited.

The malloc figure is the upper bound on what a snapshot must save for guest memory: it also holds host bookkeeping. The
split needs a counter of materialized pages by backing kind (Stage 0).

### Save and restore costs, measured on this Mac under the same load

A 2 GiB benchmark (`F_NOCACHE` for file I/O, with `fsync` after writes; memory copies into fresh pages) gave:

| operation | rate, GiB/s (three runs) |
|---|---|
| write to disk | 1.03 to 2.06 |
| read from disk, uncached | 1.11 to 1.46 |
| copy into fresh memory | 1.59 to 2.43 |

For the 2.5 GB at 30 s after the spawn, a save writes it in 1.2 to 2.4 s. A restore reads it in 1.7 to 2.3 s and copies
it into memory in 1.0 to 1.6 s: 3 to 4 s of memory work if the two do not overlap. That is the floor for memory alone.

The part this does not measure is translation. A restored machine has no translated code, and Dynarmic translates on
demand, so the code that runs after a restore is translated again. A cold boot translates 2.25 million blocks, 56 to 79
s of the translation timer, and the artifact store that would persist them is not wired on demand
(`docs/explanation/emulator/performance.md`). A restore's first seconds would therefore run at translation speed,
and the cost depends on how much code runs next. Stage 1 must measure it.

## What a machine holds, and how it would be saved and restored

Guest state falls into four groups: memory, CPU, kernel and devices, and time. For each entry the table gives how it
would be saved, how it would be restored, and what cannot be carried over.

### Memory

| state | where | save | restore | cannot carry over |
|---|---|---|---|---|
| Writable guest pages | a 4 GiB address space per guest process, 4 KiB pages, each a `GuestPageBacking` (`src/foundation/include/foundation/address_space.hpp:60-65`, `file_page_cache.hpp:229`) | every page that is not clean file-backed: anonymous pages and pages that were written after mapping | allocate the page and fill it | nothing; the host allocation is re-made |
| Clean file-backed pages (the rootfs, the shared cache, `__TEXT`) | the page cache (`src/foundation/memory/file_page_cache.cpp`) | not saved; record the key, which is path, file generation, offset and byte count (`file_page_cache.hpp:405-415`) | map the same file again; a generation mismatch refuses the mapping (`file_page_cache.cpp:1890-1893` †) | a rootfs that changed. The Lockdown plist is rewritten by the boot and by the shutdown (below); the shutdown reapply reported `changed=1` in run 1, so that file's generation changes |
| A page written after it was mapped from a file | `AddressSpace::writable_backing_locked` (`src/foundation/address_space.cpp:1458-1480`) | saved as an anonymous page, since the write detached a private copy | as an anonymous page | nothing |
| Shared writable mappings | `src/kernel/bsd/descriptor_memory.cpp:1229-1244` | the host file holds the contents (writes go back to it), so only the mapping is recorded | map the file again | the mapping is to a host file, so it is only as current as that file |

Only the first and third rows need bytes. Since clean file-backed pages are not saved, a snapshot's size tracks what the
guest wrote, not the size of the firmware.

### CPU

| state | where | save | restore | cannot carry over |
|---|---|---|---|---|
| Registers, extension registers, CPSR, FPSCR | `CpuThreadState` (`src/foundation/include/foundation/cpu.hpp:154-160`) | `save_state` copies `Regs`, `ExtRegs`, `Cpsr`, `Fpscr` from Dynarmic (`src/foundation/cpu.cpp:3052-3083`) | `load_state` writes the same four back | nothing |
| TLS (`cthread_self`) | the same struct, a `std::optional` (`cpu.hpp:159`) | not copied: neither `save_state` nor `load_state` touches it | add it to the saved set; otherwise a restored thread's TLS pointer is whatever the CPU object held last | nothing once it is copied |
| Exclusive monitor (the reservations of `ldrex`) | the emulator's `ExclusiveMonitor` shared by the guest processes (`src/foundation/cpu.cpp:2168-2187`) | the pinned Dynarmic exposes no get or set for it | clear the reservations (`cpu.cpp:5083-5092`) | the reservation itself. The architecture lets a store-exclusive fail at any time, so a guest that held one across the snapshot retries; restore is correct if it starts with reservations cleared |
| Halt reason, and the translated code | `requested_halt_reason_` (`cpu.hpp:240`); Dynarmic's blocks | the halt reason is re-applied on load; translations are not state | translate on demand | translations are not saved on demand, so the first run after a restore pays for them (see the measurements) |
| Scheduler: run queues and priorities | `XnuScheduler` `ThreadRecord` (`src/mach/include/mach/xnu_scheduler.hpp:244-265`) † | the queues and priorities | rebuild | the `enqueued_at` stamps are host `steady_clock` values; reset them |
| Per-thread execution budgets | `GuestExecutionPolicy` (`src/runtime/guest_execution_policy.hpp:27-51`) † | the budget history | rebuild | the budgets come from host-measured JIT times, so a restore on another host gets other budgets |

### Kernel and devices

| state | where | save | restore | cannot carry over |
|---|---|---|---|---|
| Mach names | per task: `std::map<TaskId, Space> spaces_` (`src/mach/include/mach/mach_namespace.hpp:113`) | the spaces | the spaces | nothing |
| Mach ports | one global `PortObjectTable` (`src/mach/include/mach/mach_port_object.hpp:40`) | the table | the table | nothing; the in-flight messages are data, and their latency stamp is a host clock used only for diagnostics † |
| Queued messages, port sets, notifications, semaphores, psynch and pthread queues † | `src/kernel/include/kernel/kernel_shared_state.hpp:1148-1328`, `darwin_psynch_runtime.hpp` † | the queues | the queues | nothing |
| File descriptors | `file_descriptors_` maps guest fd to guest path (`src/kernel/include/kernel/kernel.hpp:880`) † | fd, guest path, flags, the offset | reopen by the guest path, then seek to the offset | fd numbers are guest-chosen and lowest-free from 3 (`src/kernel/kernel.cpp:3441-3452`), so restoring them is possible, but a file that was deleted after it was opened cannot be reopened by its path |
| File offsets | per fd, `file_offsets_` (`kernel.hpp:885`) | the value | the value; `dup` copies it (`src/kernel/bsd/descriptor_memory.cpp:672` †) | nothing |
| Advisory locks | `AdvisoryFileLockRegistry`, keyed by a file identity † | the locks | the locks, keyed by the reopened file | the identity is derived from the host file, so it changes if the file is replaced |
| Host sockets | `HostSocket` holds the host `descriptor_` (`src/network/include/network/host_network.hpp:111`) | not restorable; saving records that the socket existed and its guest state (`PendingHostConnect` and friends †) | reconnect, or fail as a dropped connection | the TCP connection. On a real device a connection does not survive a sleep that is long enough, and the app reconnects; this is general iOS behaviour, not checked in this repository |
| In-process sockets: socket pairs, UDP, Unix | data with weak back-links † | the data | relink the back-links | nothing |
| Timers and alarms | `ClockAlarm`, `MachTimer`, interval timers, kevent timers, on the guest clock † | the deadlines | the deadlines | nothing, if the deadlines are on the guest clock; host-clock deadlines must be rebased (see Time) |
| Baseband | offline in every model: each model in `src/foundation/device_model.cpp` has `BasebandTransport::Offline` (10 of 10) | the baseband channel state † | the same | the transmit sink is a `std::function` † and must be reinstalled |
| IOKit | services, connections, notifications † | the tables | the tables | the host audio, display and key store objects are separate and must be reattached |
| Lockdown activation | `data_ark.plist`, written at boot (`src/runtime/emulator_session.cpp:263`) and again at shutdown unless `--activation preserve` (`:5016-5023`) | nothing: it lives in the rootfs | re-apply the lockdown state on restore, as a boot does | the rootfs can change at each boot and shutdown, so a snapshot cannot assume the file is the one it saw |
| Keybag key | `key-store-v1.key`, created once with `O_EXCL`, mode 0600 (`src/crypto/host/key_store.cpp:54`), outside the rootfs (`docs/reference/emulator/control-surface.md`) | the key file | the key file | a snapshot must carry the key, or the saved keybag blobs cannot be unwrapped |
| Keybag lock state | constants: "no passcode" and "unlocked since boot" (`src/kernel/iokit/keybag/service.cpp:25-36`) | nothing | the constants | a real device boots locked until first unlock, so a restore is not a cold boot |
| Entropy | a fresh host `getentropy` on each boot (`src/runtime/emulator_session.cpp:1286-1287` †) | the saved values | the saved values | a restore must choose: the saved values keep the keys stable, fresh ones break any key derived at boot |
| Frame buffer | guest pages (`src/graphics/include/graphics/surface_store.hpp:178-186` †) | with the memory | with the memory | nothing |
| OpenGL ES contexts | `contexts_`, keyed by integer id (`src/kernel/include/kernel/opengles_hle.hpp:79-150` †) | the context state: textures, buffers, programs and their source | recreate the GPU objects from that state | `current_context` returns null for an id that is not known (`src/kernel/graphics/opengles_hle.cpp:310-319`), so each GL call fails until the context exists again. Textures are host ARGB and byte vectors (`src/graphics/include/graphics/gles_resources.hpp:28-50` †), so they serialize; the GPU copies do not |
| Vulkan renderer | `src/host/graphics/vulkan_gles_renderer.cpp:57-63`: texture cache 128 MiB by default, 256 MiB at most, render-target pool 32 MiB | nothing: a cache | rebuilt | everything on the GPU. Reading the GPU back is possible, with a blocking copy for each dirty target † |
| Audio | SDL output: 44.1 kHz, 16-bit stereo, 1024-sample buffers (`src/app/sdl/sdl_audio_sink.cpp:241-249`) | the guest's audio objects (players, queues, volumes) † | reopen the device | the queued PCM in the host buffer; with 1024-sample buffers that is 23 ms per buffer |
| Display and input | SDL window and Vulkan presenter; HID event queue and sequence (`src/kernel/include/kernel/kernel_shared_state.hpp:369,1248` †) | the queue and sequence numbers | new window, presenter and queue | the window; the control channel's stdin belongs to the launching process |

### Time

| state | where | save | restore | cannot carry over |
|---|---|---|---|---|
| Monotonic guest time | `VirtualClock::now_` (`src/foundation/include/foundation/virtual_clock.hpp:15-35`) | the value | resume at the saved value, so the gap is invisible to the guest | nothing |
| Calendar time | `wall_time_offset_` in the same class; `synchronize_wall_time` exists | the offset | keep the saved offset, or resync to the host; the restore chooses | a resync moves the calendar by the host's error, and the guest never sees the change as a step |
| Pacer origin | `initial_host_time_` in `RealtimePacer` (`src/runtime/include/runtime/realtime_pacer.hpp:44-45`) | nothing: it is host state | anchor again at restore | the anchor is a host time; the guest's elapsed time is the saved value |
| Host-clock deadlines: scheduled input (`steady_clock`), baseband `ready_at`, the 1 ms poll cadence, the execution budgets | `src/runtime/input/live_touch_scheduler.cpp`, `live_button_scheduler.cpp` †; `src/kernel/kernel.cpp:1452-1580` † | not saved | recomputed, or rebased to the new anchor | they are host times; saving them as guest times would change when they fire |

Time is the one state with no host counterpart on a real device: the guest sees a monotonic clock that resumes where it
stopped and a calendar that is correct only if the offset is.

## What a snapshot would weigh and how long a restore would take

- **Size.** At 30 s after SpringBoard spawns, the malloc share is at most 2.2 GB. It holds guest pages together with
  host structures, and the measurements above do not separate the two. Dirty pages are 0.1 GB only because the host
  had swapped the rest; the snapshot must take the swapped pages too. The clean library pages, 0.45 GB, are not saved.
- **Save time.** 1.2 to 2.4 s for 2.5 GB on this Mac under load.
- **Restore time, memory only.** 3 to 4 s for 2.5 GB.
- **Restore time, first run.** Unmeasured. It is the translation of the code that runs after the restore. A cold
  boot translates 2.25 million blocks and spends 56 to 79 s on translation, so a restore that runs much of the same code
  pays a large part of that. Stage 3 removes it; Stage 1 measures it.
- **Disk.** About 2.5 GB per snapshot. Ten firmware and device pairs would be 25 GB under `~/.revenant`.

The comparison with a cold boot is 58 to 112 s on this Mac, depending on load and time scale, against a restore of
about 4 s plus whatever translation the first run needs.

## How other emulators save a VM

From memory of qemu's documentation, not re-read in this session and not copied: `savevm` and `loadvm` store the VM as
a stream of sections. Each device model declares its state as versioned fields, and RAM is saved page by page with a
dirty bitmap, so a second snapshot writes only what changed. Migration uses the same stream. The ideas that fit this
emulator are these.

- Version each subsystem's saved state. The HLE kernel has no schema today, so a snapshot made by one build could be
  misread by another. The emulator already keys translations on the Dynarmic build fingerprint; the snapshot should key
  on the emulator build too.
- Use the copy-on-write detach as the dirty bitmap. The emulator already marks a page written when it detaches a private
  copy (`src/foundation/address_space.cpp:1458-1480`), so the snapshot's dirty set is available without scanning memory.
- Keep the stream format apart from the in-memory layout, so that the Mach and fd tables can change without breaking
  files already written.

The Light Touch project and its qemu-ios fork were read on GitHub on 2026-10-24, per
`docs/explanation/emulator/performance.md`. That reading covers block chaining, the indirect-branch cache, and
`savevm` and migration. Its `JIT-SNAPSHOTS.md` covers statistics, not machine snapshots, so it adds no design for this
emulator beyond the qemu ideas above.

## Stages

The owner decides the stages. Each lists what it touches, what it costs in measured terms, and what it risks. None
has been built.

- **Stage 0: measurement.** Define the ready point for a plain boot: a settled display that is not the logo, or the
  control channel's `settle` (`docs/reference/emulator/control-surface.md`) on a non-logo frame. Add a counter of
  materialized guest pages by backing kind to `--perf-summary`, which splits the malloc figure into guest and host.
  Measure on a migrated rootfs. Touches the page counters and the perf summary; a small change. Risk: low.
- **Stage 1: daemons only.** Snapshot a machine that runs the `run` profile, which has no SpringBoard, no SDL, no GL and
  no audio, so it holds only memory, CPU, scheduler, kernel tables, the clock and the rootfs. Restore into a new
  process, check the Mach services and the processes match, and measure the size, the save, the restore and the
  translation of the first run. Touches the serialisation of the kernel and Mach tables, which is most of the work. Its
  first risk is a host pointer in a kernel object that neither the survey nor this page found.
- **Stage 2: SpringBoard.** Add the GL context state, the audio objects, the display and input re-attachment, and
  the keybag key. Touches the graphics HLE, the audio, SDL, and the key file. Its risks are GPU fidelity and the
  difference between a restored device and a cold boot's locked state.
- **Stage 3: persisted translation.** Make the translations of a snapshot's code part of the snapshot, or import them on
  demand from the artifact store. This is the blocker the performance reference already names, and it is what makes
  a restore fast after its first run.
- **Stage 4: harness integration.** Key a snapshot on the rootfs content, device, firmware build and emulator build.
  Refuse a restore when the rootfs changed. Handle the Lockdown rewrite, which changes the rootfs on every boot.

Stage 1 is the one to decide first. The tests that do not need SpringBoard (daemon, library and tweak tests, per the
performance reference) can use this profile, it needs no GPU or audio state, and its numbers would replace the
translation estimate above with a measurement.

## Open questions

- Whether a restore must reproduce the cold boot's locked keybag, or may come up unlocked as a boot does today.
- Whether a snapshot may carry the keybag key, which lives outside the rootfs, or must be regenerated per restore.
- The size of the malloc share that is guest memory, which Stage 0 answers.
- The translation cost of the first run after a restore, which Stage 1 answers.
