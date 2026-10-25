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
  unavailable outside the test harness. A plain boot logs the spawn line and, since Stage 0, the finished-startup
  milestone (see Stage 0 results).
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

## Serialisation design, from the code

Scope is the `run` profile (`docs/reference/emulator/performance.md`, "Run profile"): a boot without SpringBoard, whose
clone has the SpringBoard LaunchDaemon removed. It holds launchd and its daemons, and the runner writes `results/verdict.json`. A snapshot
is taken at a scheduler point the machine reaches itself (quiescence, below), never in the middle of an instruction.

The unit is one `Runtime` per guest process (`src/runtime/process.hpp:131`: `memory` (AddressSpace), `cpus`
(CpuCluster), `kernel` (CompatibilityKernel)), plus the state the kernels share: `KernelSharedState`
(`src/kernel/include/kernel/kernel_shared_state.hpp`, 1,727 lines), the virtual clock, and the host-side objects.

Each row names an owner, where it lives, what it holds, and what the snapshot does with it. Save means written as data.
Rebuild means recomputed at restore from the rootfs or the device configuration. Refuse means the snapshot is not taken
while the state exists.

| owner | where | holds | treatment |
|---|---|---|---|
| pages | `AddressSpace::Page` (`src/foundation/include/foundation/address_space.hpp:255`), `GuestPageBacking` (`file_page_cache.hpp:229`) | 4 KiB bytes of each materialised page, write generation, flags `file_cached`, `shared_writable`, `copy_on_write_possible` | save anonymous and shared-writable bytes. Name file-cached pages by their `RuntimeBackingGeneration` (`file_page_cache.hpp:36`: backing path, `GuestFileGeneration`, `ContentIdentity`), offset and size, and read them back from the file |
| mappings | `AddressSpace` regions, `FileMapping` (`address_space.hpp:264`), permission chunks | ranges, permissions, file offsets | save ranges and permissions; rebuild file mappings from the file key |
| shared backings | `shared_ptr<GuestPageBacking>` referenced by pages in one or more processes | one backing, several referrers | save each backing once under an identity; pages refer to the identity |
| CPU | `CpuThreadState` (`cpu.hpp:154`): 16 registers, 64 extension registers, cpsr, fpscr, `cthread_self` | per-thread registers | save all five. The JIT save and load (`cpu.cpp:3061`, `3085`) copy only the first four, so `cthread_self` is written explicitly. The exclusive monitor is cleared on restore (`Cpu::clear_exclusive_state`). Translated code is not state |
| scheduler | `XnuScheduler` (`src/mach/include/mach/xnu_scheduler.hpp`): `threads_` (307), `process_threads_` (310), `processor_run_queues_` (306), counts `runnable_count_`, `waiting_count_`, `active_timeshare_count_` (314–316) | thread records, queue order, counts | save the records and queue order; recompute the counts on restore and check them against the saved ones |
| clock | `VirtualClock` (`virtual_clock.hpp:15`): `now_`, `wall_time_offset_` | guest time | save both. The pacer (`RealtimePacer`, `realtime_pacer.hpp:24`, with its initial host time at line 46) is rebuilt at restore. Deadlines held in host time convert to guest time |
| per-process kernel tables | `CompatibilityKernel` (`kernel.hpp:80`), members at 844–1024 | descriptors (`file_descriptors_` 885, `file_offsets_` 890, `file_status_flags_` 893, `descriptor_flags_` 894, `descriptor_guards_` 895, `virtual_descriptors_` 897, `duplicated_descriptors_` 921), signals (`signal_actions_` 933, `thread_signal_masks_` 934, `pending_signals_` 942, `alternate_signal_stacks_` 950), kqueues (`kqueues_` 929), socket options and names (`socket_options_` 920, `bound_socket_names_` 914), `random_state_` (962), `guest_working_directory_` (880), `process_image_` (882) | save the plain data. The maps keyed by id keep their keys. A descriptor that names a host file reopens at restore from its path, offset and flags, and the restore fails if the file key has changed |
| host network objects | `host_sockets_` (905), `virtual_udp_sockets_` (911), `unix_listener_states_` (917), `route_socket_states_` (927), `pending_host_connects_` (999) and the other host pending maps | host descriptors and operations in flight | refuse while any exists. The `[loader]` line prints `network=` from the host network policy (`emulator_session.cpp:2155`); the policy in force for the `run` profile is the first thing to measure |
| handlers | `CompatibilityKernel` handler members, `kernel.hpp:966–990` (19 in all, from `thread_create_handler_` to `mapped_executable_handler_` and the rest) | callbacks into the session | not saved. The session rewires them at restore, in the order spawn uses |
| blocked operations | `pending_waits_` (993), `pending_mach_receives_` (994), `pending_kevents_`, `pending_recvmsgs_`, `pending_timers_`, `pending_semaphore_waits_`, `pending_psynch_waits_`, `pending_polls_`, `pending_selects_` and the rest through line 1024 | what each blocked thread waits for | save waits on guest state (a timer, a Mach receive, a semaphore, a psynch wait) as kind and deadline. Refuse waits that depend on host state |
| Mach IPC | `spaces_` (`mach_namespace.hpp:113`: per-task names and rights), `objects_` (`mach_port_object.hpp:165`), `mach_queues` of `MachMessage` (`kernel_shared_state.hpp:1150`, struct at 442), `mach_semaphores` (1318), `mach_memory_entries` (1322) | names, rights, queued messages, semaphores, memory entries | save all of it. Port ids and names keep their values |
| shared kernel state | `KernelSharedState`: `processes` (`std::map<std::uint32_t, ProcessRecord>`, line 1412; `ProcessRecord` at 537: uid, gid, command, executable path, arguments, environment, entitlements, incarnation), `bootstrap_checked_in_services` (1239), `psynch_runtime` (1417), `MachMemoryObject` (937) | per-machine tables | save the tables that carry state. Rebuild derived data (the launchd job catalog, device strings, Darwin identity) from the rootfs and the configuration |
| notify bus | `DarwinNotifyStateHle` (`darwin_notify_state_hle.hpp`): `SharedBus` `registrations` (71–73, shared through `bus_`, line 88), `token_names_` (78), `virtual_tokens_` (79), `next_virtual_token_` (80) | (process, token) keys with name and port; virtual tokens | save the registrations as (process, token, name, port) and the token tables. Providers and the dispatcher are callbacks, rebuilt at restore |
| graphics, HID, audio, UI | `KernelSharedState`: `hid_event_queue` (369), `graphics_services_capability_memory` (377), foreground transitions (about 815–830), touch transform (897); `DisplayState` (`graphics/include/graphics/display.hpp:57`), `WifiState` (`network/include/network/wifi_state.hpp:65`), `AudioService` (`media/include/media/audio.hpp:87`) | display, touch, audio and foreground state | not saved. Refuse while a transition or an input is pending. Rebuild the rest from the configuration |
| IOKit | `IOKitService` and `IOKitRegistryProperty` (`kernel_shared_state.hpp:580`, 620), connection states from `IOKitConnection` (648) on | registry and connection state | rebuild the registry from the device model. Save connection state |
| device state | lockdown `data_ark.plist` (`device_state/lockdown_state.cpp:237`, applied at boot in `EmulatorSession::run` at `emulator_session.cpp:264` and reapplied at shutdown at line 5051), `baseband_device_state` (`kernel_shared_state.hpp:1376`), `KeyStore` (forward-declared at line 68) | files and host state | the files stay in the rootfs and are not part of the snapshot. The keybag and key store are proposed for a later stage |
| translation | JIT caches and the artifact store (`foundation/jit_artifact.cpp`), with `--jit-artifact-disk-mib` at 256 MiB by default (`src/app/main.cpp:651–657`) | native code | not saved. A restored run reuses the disk artifacts by default; measure with and without |
| host | rootfs path, dyld cache, host threads, display presenter, host network | host-only | rebuild |

Quiescence. A snapshot is taken at a scheduler point where every saved category is in a serialisable state and every
refused category is empty. The session names the first refused category it finds, and a refused snapshot is not written.

Format. Little-endian. A header holds the format version, the emulator build identity, the device model, the rootfs
content identity and the profile. Then one section per owner above, each with its own version and length, so a reader
rejects a section it does not know. Pages are written as address, flags and a backing index, with each backing's 4 KiB
written once. Identities keep the values the guest sees (pids, port names, thread ids, descriptors). Host pointers are
never written.

Restore. Validate the header and refuse on any mismatch in build, device or rootfs identity. Rebuild the host objects,
create the processes and address spaces, load the pages and mappings, load the CPUs and the scheduler, load the kernel
tables, rewire the handlers, and restart the clock and the pacer at the saved guest time. Restore starts from quiescence,
so nothing is in flight.

Round-trip test. (1) Cold boot of the `run` profile to the runner's verdict, recording the results and the `[process]`
lines after the snapshot point. (2) Cold boot to the snapshot point, take the snapshot, continue to the verdict. (3)
Restore the snapshot, continue to the verdict. The oracle is that the verdict and results of (1), (2) and (3) are equal,
and that the `[process]` lines after the snapshot point match. Timing is cold to verdict against restore to verdict, in
wall time and CPU time, with the translation cache empty and then with the disk artifacts present.

Measured, the pending state of a `run`-profile boot (`--verbose --perf-summary`, counts taken at quit, not at a defined
quiescent point). Each cell is the largest count in any runtime, then the number of runtimes with a non-zero count, at a
120 s window (21 processes) and a 600 s window (63 processes):

| map | 120 s | 600 s |
|---|---|---|
| `pending_waits_` | 0 | 0 |
| `pending_mach_receives_` | 1 / 7 | 10 / 39 |
| `pending_kevents_` | 0 | 2 / 57 |
| `pending_semaphore_waits_` | 1 / 1 | 3 / 19 |
| `pending_psynch_waits_` | 0 | 4 / 3 |
| `pending_signal_suspends_` | 0 | 1 / 11 |
| `pending_selects_` | 1 / 1 | 1 / 4 |
| `pending_io_poll_cache_` | 2 / 1 | 7 / 60 |
| `pending_event_processors_` | 2 / 8 | 17 / 62 |
| `host_sockets_` | 3 / 1 | 3 / 2 |
| `unix_listener_states_` | 11 / 20 | 11 / 7 |
| `virtual_udp_sockets_`, `route_socket_states_`, host connects, accepts and writes, baseband writes, flocks, record locks, polls, timers, recvmsgs, socket reads, unix accepts | 0 | 0 |
| `kqueues_` | 2 / 21 | 5 / 63 |
| `file_descriptors_` | 0 | 12 / 19 |
| `virtual_descriptors_` | 35 / 21 | 80 / 63 |
| `thread_pending_signals_` | 3 / 20 | 19 / 63 |

Reading: no runtime ever held a `pending_waits_` entry, and the host connect, accept and write maps and the baseband
writes stayed empty. Mach receives, kevent, semaphore and psynch waits, signal suspends, io-poll caches and event
processors are non-zero in a running guest, so a snapshot must save them as guest-state waits or wait for them to drain.
Host sockets are present in one or two runtimes, so the host-network refusal in the table will fire on a `run` boot
unless those sockets are closed first. These counts are at quit; the quiescent point is still undefined.

Still open: whether a quiescent point exists where the waits and host sockets above are empty, and how long a restore
takes for about 1 million pages, of which about 0.9 GiB are anonymous or shared-writable.

## Loop state in run(), classified

`EmulatorSession::run` (`src/runtime/emulator_session.cpp:186`) keeps its scheduling state in locals. The scheduler loop
starts at line 2783 and its teardown is at about 5047. A local is listed here when it is declared before the loop and is
read or written inside it, or inside a lambda defined before the loop that the loop calls. Save means written to the
snapshot. Rebuild means set from the configuration, the rootfs or the restored kernels. Refuse means the snapshot is not
taken while the value is set.

| local | declared | holds | treatment |
|---|---|---|---|
| `scheduler` | 1482 | `XnuScheduler`: thread records, run queues, counts (owner in the table above) | save with the scheduler owner |
| `last_serial_thread` | 1493 | the thread that ran last in the serial slice order | save |
| `scheduler_handoff_thread` | 1494 | the explicit handoff target the dispatch policy reads | save |
| `display_urgent_process` | 1495 | the process that holds a realtime display lease | refuse while set |
| `display_urgent_thread`, `display_urgent_receiver_thread`, `display_yielded_thread` | 1496 to 1498 | guest thread ids of the display callback | refuse while a callback is in flight; save otherwise |
| `display_inflight_callback_thread` | 1499 | the callback in flight | refuse while set |
| `display_inflight_callback_sequence` | 1500 | the sequence of the callback in flight | save (0 at quiescence) |
| `display_callback_pending_reported` | 1507 | whether the pending-callback line was printed | rebuild as false; it gates a print only |
| `diagnostic_svc_spin_thread`, `_calls`, `_report_at` | 1508 to 1510 | counters for the spin report | rebuild; they gate a print only |
| `diagnostic_display_yield_count` | 1511 | count of display yields, capped at 32 by the check at 3991 | save; the cap changes scheduling |
| `remaining_ticks` | 2159 | ticks left in a bounded run | save the tick count at the snapshot; the restored bound is the cold bound minus that count |
| `consumed_ticks`, `stopped_pid`, `stopped_cpu`, `stopped_result` | 2160 to 2163 | the values reported at exit | not state; recomputed at exit |
| `hard_stop`, `initial_failure` | 2164, 2165 | exit conditions | refuse while set |
| `gdb_server`, `debug_request` | 2166, 2167 | a debugger attached to the session | refuse while attached |
| `realtime_pacer` | 2194 | host-time pacing | rebuild |
| `display_performance_window`, `display_clock_window` | 2255, 2264 | host-side display timing windows | rebuild (reset) |
| `display_scanout_owner` | 2265 | `Runtime*` of the scanout owner, a host pointer | rebuild from the foreground process |
| `observed_display_submissions`, `last_display_submission` | 2295, 2297 | host-time display observation | rebuild (reset) |
| `transition_process` | 2305 (lambda) | the destination of a foreground transition | refuse while a transition is pending |
| `last_jit_quota_refresh`, `latest_host_memory_budget`, `pressure_reclamation_applied` | 2461 to 2463 | JIT memory pacing | rebuild |
| `guest_idle_since` | 2464 | host time since the guest went idle | rebuild (reset) |
| `guest_timer_overshoot_samples`, `_total_nanoseconds`, `_max_nanoseconds` | 2465 to 2467 | timer measurements | rebuild (zero) |
| `observed_guest_timer_deadline` | 2468 | cached next guest deadline | rebuild from the kernels' timers |
| `guest_deadlines` | 2469 | per-process deadlines, upserted from `timer_deadline_snapshot()` (2474 to 2489) | rebuild by the same refresh after restore |
| `executed_time_clock`, `executed_ticks_since_catch_up` | 2519, 2520 | guest tick accounting and catch-up | save the tick counter; rebuild the clock from `guest_ticks_per_second` |
| `last_interactive_host_activity` | 2763 | host time of the last input | rebuild |
| `interaction_generation` | 2764 | input generation counter, starts at 1 | save |
| `input_receiver_process` | 2765 | the process that receives input | save; refuse while input is pending |
| `pending_touch_input_completion`, `pending_button_input_completion` | 495, 496 | input in flight | refuse while set |
| `touch_replay`, `live_control`, `live_button_scheduler`, `live_touch_scheduler` | 471 to 474 | input replay and the control channel | refuse while a replay is active; rebuild otherwise |
| `display_presenter`, `frame_file_presenter` | 469, 470 | host display output | rebuild |
| `runtimes`, `runtime_index` | 621, 683 | the processes; the pid index over them | `runtimes` is the per-process owner; rebuild the index |
| `jit_code_cache_governor`, `runtime_reaper`, `runtime_jit_memory`, `host_resources`, `artifact_compaction_*` | 593 to 771 | JIT and host work | not saved; rebuild |
| `jit_work_signal` | 1095 | the work signal shared with the JIT | rebuild |
| `baseband_output_path`, `baseband_capture_stream`, `baseband_capture_bytes` | 549 to 551 | host output for baseband capture | rebuild; the byte count is output only |
| `debug_target` | 1481 | the debugger adapter over `runtimes` | rebuild |
| `guest_execution_policy`, `guest_dispatch_policy`, `guest_parallelism_policy` | 1486 to 1492 | policies built from the configuration | rebuild |
| `options`, `host`, `device`, `darwin_abi`, `rootfs`, `session_catalog`, `activation`, `lockdown_capabilities`, `guest_architecture`, `guest_ticks_per_second`, `guest_processor_count`, `profile_*` | 191 to 372 | configuration and host objects | rebuild; the header identity check covers them |
| `initial_runtime`, `catalog_maintenance` | 1474, 1475 | pointer to the initial process; host catalog maintenance | rebuild |

The scan is approximate. It found the names used in the loop body and followed the lambdas defined before the loop that
the loop calls, by hand. A name used only inside such a lambda and not listed here is a gap. The round-trip oracle and its
negative control are the check for a missed field, not this table.

## Stages

The owner decides the stages. Each lists what it touches, what it costs in measured terms, and what it risks. Stage 0
is built (see its results below). Stages 1 to 4 have not been started.

- **Stage 0: measurement.** Define the ready point for a plain boot: a settled display that is not the logo, or the
  control channel's `settle` (`docs/reference/emulator/control-surface.md`) on a non-logo frame. Add a counter of
  materialized guest pages by backing kind to `--perf-summary`, which splits the malloc figure into guest and host.
  Measure on a migrated rootfs. Touches the page counters and the perf summary; a small change. Risk: low.
  Built in `74c580bee` (counters, milestone, tests) and `23f3de3b7` (the notify hooks, below). Measured on the plain
  rootfs, not a migrated one.

### Stage 0 results

The ready point is `[boot] milestone=springboard-finished-startup`, logged when SpringBoard posts
`com.apple.springboard.finishedstartup`. The hook is `_notify_post` in `libsystem_notify.dylib`, where that symbol is
defined. The notify HLE does not record it on its own: `publish()` logs nothing, and the notify hooks had been
registered under `libSystem.B.dylib`, which installs none of them. Five of the six
registrations were dead for that reason; `23f3de3b7` moves them to `libsystem_notify.dylib`. `__notify_lib_init` is not
exported, but it is a local symbol of that image. The 6.1.3 cache holds the local symbols in its main file (header
`localSymbolsOffset` 0x0c985000, `localSymbolsSize` 0x01ee15ff), so the earlier note that it had none was wrong. Reading
them needed two fixes: `apple.dyld` assumed 16-byte entries for the 32-bit cache (the entries are 12 bytes), and the
emulator's image symbols came only from the stripped `LC_SYMTAB`. With both, the guard installs (`functions=7` on every
`libsystem_notify` line) and the provider-initializer guard from `27048fc11` is active.

Plain boots, with the milestone reached in some and not others:

| run | window | milestone (s after launch) | spawns | notify posts | materialized pages |
|---|---|---|---|---|---|
| before, six hooks dead | 1202 s | 668 | 84 | 411 | 1,052,203 |
| after, six hooks live (1) | 1203 s | not reached | 74 | 101 | 1,015,378 |
| after, six hooks live (2) | 1804 s | 1466 | 84 | 396 | 1,088,970 |
| plain, earlier build, six hooks dead (3) | 1800 s | not reached | 76 | not logged | 945,063 |

Run 3 was a concise log, so it has no post count. The same build as run 3 reached the milestone at 1218 s in an earlier
run. The SpringBoard spawn moved from 116 s (before) to 161 s (after 1) to 337 s (after 2), so the host's load sets the
timing and a window of 20 to 30 minutes can miss the milestone. The before run and after 2 spawned the same 83
programs, and their notify names differed only by three now-playing names that appeared in the before run.

Materialized pages by backing kind (a page mapping, counted per address space, so a backing shared by several
processes counts once for each):

| run | anonymous | file-cached | copy-on-write-possible | shared-writable |
|---|---|---|---|---|
| before, 20 min, 60 processes | 30,052 | 812,966 | 326 | 208,859 |
| after (2), 30 min, 62 processes | 30,954 | 839,314 | 343 | 218,359 |

File-cached pages are clean copies of file content that a snapshot can name by file instead of saving. Anonymous and
shared-writable pages are the bytes a snapshot must save: about 30,000 anonymous pages (about 120 MiB) and about 210,000
shared-writable pages (about 0.8 GiB). The shared-writable figure is an upper bound, since a shared object can appear in
several processes. So Stage 0's answer to the open question below is that the guest state to save is under 1 GiB at
20 to 30 minutes, well below the malloc figure of the earlier 30-second sample (2.2 GB written). The rest of that malloc
figure is host bookkeeping per page.
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
