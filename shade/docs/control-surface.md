# Shade: what a test harness can drive

Everything here comes from reading the source of `shade/` (with the lab patches) and from runs in
`runs.noindex/`. Paths are relative to `shade/`.

## Launch

    env TMPDIR=<lab>/tmp.noindex VK_ICD_FILENAMES=<lab>/deps/build-swiftshader/Darwin/vk_swiftshader_icd.json \
      shade/build/shade boot --rootfs <run>/rootfs --device iPhone3,1 --host-cache <cache> \
        --display headless --gles-backend software --control-stdin --frame-output <run>/frame.png

* `--device`: iPhone1,1 iPhone1,2 iPhone2,1 iPhone3,1 iPhone4,1 iPod1,1 iPod2,1 iPod4,1 (lab patch)
  iPad1,1 iPad2,1 (`src/foundation/device_model.cpp`).
* The release comes from `System/Library/CoreServices/SystemVersion.plist`; `9A*`, `9B*` map to
  darwin11, every `10*` build to darwin13 (`src/device_state/darwin_kernel_configuration.cpp`).
  An unknown build refuses to boot.
* The guest writes straight into `--rootfs`; there is no overlay. Shade also creates
  `dirname(rootfs)/runtime/shm/` and `dirname(rootfs)/.shade-device-state/` (key store). So every
  run gets its own directory holding an APFS clone (`cp -c -R`) and nothing else.
* `--activation activated` (default) rewrites `private/var/root/Library/Lockdown/data_ark.plist`
  and hooks liblockdown's activation queries; it does not touch Setup Assistant.
* `--network host` (default) gives guest sockets real host sockets; parallel guests share the host
  port space. `--network isolated` refuses inet sockets.
* `shade boot` exits 0 on `quit`, when pid 1 exits, when `--ticks` run out; 1 on an internal error
  (failed snapshot write, gdb disconnect, scheduler stall). The guest's exit code is never the
  process exit code: parse `[process] exit pid=N status=S [signal=G]`.

## `--control-stdin` (`app/control/live_control.cpp`, `src/runtime/emulator_session.cpp`)

One command per line; `#` comments; EOF on stdin does not stop the emulator (send `quit`).
Replies are log lines starting with `[control]`. Ready marker: `[control] ready; use help for commands`.
Coordinates are UI points, portrait, origin top-left: 320x480 on iPhone/iPod, 768x1024 on iPad.

| command | reply |
|---|---|
| `tap X Y [hold-ms]` | `[control] gesture=tap scheduled events=2`, later `[transition] input-complete` |
| `drag X1 Y1 X2 Y2 [duration-ms] [steps]` | `gesture=drag scheduled` |
| `touch down/move/up/cancel X Y` | `touch queued` |
| `home` (`wake`), `lock [hold-ms]`, `unlock` (home + slide gesture of the profile) | `home requested`, `gesture=unlock scheduled events=14` |
| `button home/lock/volume-up/volume-down down/up`, `hold BUTTON MS`, `volume-up`, `volume-down`, `ringer ring/silent` | `button event queued` ... |
| `snapshot PATH` (.png/.bmp/else PPM) | `snapshot=PATH frame=N` (a failed write kills shade) |
| `snapshot-sequence PREFIX INTERVAL-MS COUNT` | one line per PPM |
| `settle` | `[transition] settle id=N`, then `[transition] internal-stable id=N` once the display content has not changed for 60 display periods of guest time, counted from the frame on screen (its `input-complete-ns` is the settle's start). Without `--ticks` the guest clock follows the host's whether or not the guest ran, so the window counts only the guest time the guest had: a catch-up (`host-syncs=`) counts the later of what the guest executed since the previous one and, when it had nothing runnable, the time it waited up to its earliest timer or VSync deadline, both from the previous catch-up (the guest clock stands still while it executes); the rest, time it was owed and did not get, is left out (`starved-display-periods=`), and `stable-display-periods=` is what was counted. Like an input, it replaces the transition being watched |
| `status` | `status frame= submitted-frame= processes= threads= runnable= active-process= display-power=on/off` |
| `ps [PID/NAME]` | `process pid= ppid= state= exit= signal= name= path=` per process, then `processes matches=N` |
| `threads PID/NAME` | pc/lr/sp, frame-pointer backtrace, wait reason per thread |
| `perf-begin LABEL` / `perf-end` | with `--perf-summary` only |
| `quit` | `quit requested` |

`ps`/`status` are the screenshot-free way to ask "is SpringBoard alive, did the app exit".
Shade itself also dumps `threads` of any process that dies on a signal.

## Other inputs and outputs

* `--touch-replay FILE`: lines `<absolute-ms-from-start> down|move|up|cancel X Y`, non-decreasing.
* `--frame-output FILE`: rewritten atomically (tmp + rename) on every submitted frame; each frame
  logs `[display] frame=N visible-pixels=P`. The display sleeps after about a minute without input
  (`visible-pixels=0`, `display-power=off`); `home` wakes it.
* `--gdb PORT`: 127.0.0.1 only, waits for the client before pid 1 runs; all processes as `pPID.TID`;
  core registers only (no VFP), software breakpoints only, dropped on exec. lldb: `gdb-remote PORT`.
* `--binary PATH` replaces launchd as pid 1; `--guest-command CMD` gives it `-c CMD`
  (so `--binary /bin/sh --guest-command '...'`, if the firmware has a shell). The run ends when pid 1 exits.
* `--ticks N`: deterministic clock, stops after N guest CPU ticks or when every thread idles.
* `--perf-summary`: one `[perf]` line with fork/exec/abnormal-exit counters at exit.

## Guest output

* A guest fd 1/2 that nobody redirected, and `/dev/console`, are copied raw into the shade log.
  launchd sends daemons' stdout to `/dev/null` unless the job has `StandardOutPath`.
* There is no host-side syslog: the guest's own syslogd/ASL write into the rootfs. The launchd
  vproc log appears as `[launchd-log] pid=1 ... message=...`.
* Emulator-detected crashes: `[cpu] fatal pid= pc= lr= fault= access= size=`, then
  `[process] exit pid= status=0 signal=11` and a `[control] thread ...` dump.

## Milestones without screenshots (what `scripts/summary.py` reads)

| milestone | line |
|---|---|
| emulator up | `[control] ready` |
| boot logo | `[display] frame=1` |
| process launched | `[process] spawn-setexec pid=N parent=1 ... PATH argv=...`, `[process] exec pid=N PATH` |
| backboardd/SpringBoard owns the display | `[display] scanout-owner pid=N` |
| data migration (iOS 6 first boot) | frames with small `visible-pixels` (logo + progress bar) |
| Setup Assistant (when not skipped) | spawn of `/Applications/Setup.app/Setup` |
| SpringBoard UI finished launching | `did-finish-launching pid=N SpringBoard` in `/private/var/charon/events.log` (charon-inject.dylib) |
| app launched / alive / crashed | `app-did-finish-launching`, `app-alive` in events.log; `[process] exit ... signal=`; `ps NAME` |
| test finished | `/private/var/charon/verdict.json` (charon-runner), `[process] exit pid=<runner>` |

## Host cache and speed

* `--host-cache DIR`: `executable-catalog.bin` (Mach-O scan keyed by absolute host path + inode,
  so a fresh clone rescans: ~5 s), `jit-artifacts.bin` (translations keyed by content SHA-256 +
  CPU model + ABI; flock-guarded; reusable across clones), `vulkan-pipeline-cache.bin`.
  Temporary file names in that directory are not unique per process, so parallel runs must not
  share one cache directory.
* `$TMPDIR/shade-shared-cache-<uid>/`: content-addressed copies of mapped guest files, designed to
  be shared by all runs.
* Guest trees must live in `*.noindex` folders: Spotlight indexing clones took ~2.5 host cores.
