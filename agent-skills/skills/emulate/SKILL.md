---
name: emulate
description: Check the app on an emulated old iPhone, iPod touch or iPad with Revenant's `xmake emulate` (the emulator) — add the emulator to the project, install the app's .deb and its dependencies into the image of the chosen device and iOS release, run a program in it and read the verdict (pass, fail, crash, timeout, boot-blocked), its output, log and last frame, or launch the app itself through SpringBoard and send it taps. Says which devices and releases boot, what a verdict proves, and what the emulator cannot show. Use after a green build, for the "check in the emulator" step, or when asked to run the app in the emulator, on iOS 3 to 6, on an iPhone 3GS, 4, 4S.
---

# Check in the emulator

`xmake emulate` boots the chosen firmware's own userland (launchd, SpringBoard, the system
daemons) in the emulator, Revenant's emulator, on the user's Mac, installs the project's packages into that
image and runs one program in it under a deadline. The outcome is a **verdict** with evidence on
disk. Read `PROJECT.md` first: `## Target` names the devices and the releases to check. Each pair
checked here gets a line in `## Progress`.

**Read "Checking an app" (§5) before promising the user anything.** The emulator launches an
application through SpringBoard (`xmake emulate launch`), so what it proves is what that launch
shows: the app came up, drew, and took the taps you sent.

## 1. What the emulator covers

- **Host:** macOS on Apple silicon only; anything else is refused before it starts.
- **Devices** (the emulator profiles): `iPhone1,1`, `iPhone1,2`, `iPhone2,1` (3GS), `iPhone3,1` (4),
  `iPhone4,1` (4S), `iPod1,1`, `iPod2,1`, `iPod4,1`, `iPad1,1`, `iPad2,1`. No armv7s or arm64
  device: nothing from the iPhone 5 on. A device without a profile is refused, never replaced.
- **Releases** (the emulator's Darwin kernels, chosen by firmware build): most releases from iPhone OS 1
  to iOS 7, with gaps among the point releases (3.1.x, 4.1 and 4.3.1 to 4.3.5 among them), and
  none from 8.0 on — iOS 8 and 9 cannot be emulated. A release without a kernel is refused with the
  list of kernels the emulator has.
- **What boots:** firmware from iPhone OS 3.0 through iOS 6.1.3 boots in Revenant's acceptance
  runs; iOS 7 is declared and has never been booted. Not every device and
  release pair inside that range has been booted: until one has on this machine, tell the user the
  check may not be possible. A pair that does not boot fails at its first `install` (§3), before
  any run.
- `-r RELEASE` picks the device's **earliest firmware not older than** that release: `-r 6.1` on
  an iPhone 4S emulates 6.1 (10B142), not 6.1.3. Pass the exact release from `PROJECT.md`; the
  line the run prints names the version and build actually emulated, record that one.
- No audio for a program `run` starts: `AudioSessionInitialize` answers `'ini?'` and the log says
  `Couldn't connect to com.apple.audio.AudioSession` (measured on iPhone 4S 6.1.3), because the
  audio server is not running yet (§4). Audio is unchecked here, not the app's fault. No network
  unless asked (§3), no camera, no GPS, no cellular. The display is drawn in software.

## 2. Add the emulator to the project

1. After the `includes("@addon/revenant/apple-ios")` line of `xmake.lua`, add
   `includes("@addon/revenant/emulate")`. It requires `revenant@emulator` (the emulator, built with xmake
   from `emulator/` of the checkout on first use), `revenant@swiftshader` (its CPU graphics
   driver) and `revenant@emulator-guest` (the runner that starts your program in the guest).
2. Configure again so they are installed: `xmake f -p iphoneos -a armv7 -y > .logs/config.log 2>&1`.

Check: `xmake where emulator` prints an install folder; the configure output has no `error:`.

**Disk and time, first use of a device and release:** the root filesystem is downloaded from
Apple's servers and unpacked into `.cache/firmware/rootfs/<device>/<version>_<build>/` (about
1.2 GB for an iOS 6 iPhone; skill `firmware`), then booted once past its first-boot data migration
into a **golden image** under `.cache/emulator/golden.noindex/` (about 1.5 GB, about 5 host
minutes for iOS 6). Every later install and run is an APFS clone of it: seconds and almost no
space. A golden image is keyed by device, build and the emulator package: a changed emulator, which is a new
package, builds a new golden image and removes the old one.

## 3. Install the app's packages into the image

Always name the device and the release; the defaults (`-r` = `apple_minimum`, `-d` = the first
device of the configured architecture) rarely match `PROJECT.md`.

```
xmake emulate -y -d iPhone4,1 -r 6.1.3 install > .logs/emulate-install-iPhone4,1-6.1.3.log 2>&1
```

`install` runs `xmake deb` first (the whole packaging of skill `package`: build, stage, sign,
imports refused rather than warned), then clones the golden image and unpacks the data of **every
.deb that step wrote** — the app's — and runs each package's `preinst` and `postinst` against
the image the way dpkg does (`DPKG_ROOT`). An application that links the Backports libraries cannot
be packaged at all yet: the one package that installs those libraries is not written, so the
packaging stops and names the target. What `xmake deb` refuses is not
installed: at this pin a Swift program that carries its runtime stops `xmake emulate install` with
`error: these imports are not exported by the device's iOS:` (measured; skill `swift` §7).

Check: one line `installed <file>.deb into <device> <version>` per package, and no `refused this
image`. The first `install` on a device and release also boots and builds its golden image; if that
boot fails, `install` stops with `<device> <build> did not get past <stage> within <n> seconds; the
emulator log is <path>`. No run and no verdict follow: record the pair as "not checkable here" and
tell the user. It does **not** run `uicache`: SpringBoard of that image does not know the app's icon.

Network: the guest has none by default (`isolated`). `-n loopback` or `-n host` on `run`, or
`set_values("emulate.network", "host")` on a target, gives it one; `host` shares the Mac's real
sockets.

## 4. Run a program and read the verdict

```
xmake emulate -y -d iPhone4,1 -r 6.1.3 [-s 60] run /absolute/path/in/the/guest [ARGS...] > .logs/emulate-run.log 2>&1
```

A fresh clone of the installed image boots; launchd starts `revenant-runner` (from
`/etc/launchd.conf` up to iOS 6.x, from a LaunchDaemon from iOS 7), which starts
the command **as root** with a deadline of `-s` seconds (default 60). Up to iOS 6.x it starts
early in the boot: when it runs, the guest holds only launchd, launchctl, the runner and the
command (measured on iPhone 4S 6.1.3), so an API that needs a system daemon (the audio server
among them) finds none. The runner writes the command's exit status and output into the guest. The boot is stopped as soon as the
verdict exists, and killed after `-t` seconds (default 900) whatever happens. Expect several host
minutes per run.

A pass prints `pass on <device> <version> (<build>) in …`; any other verdict stops the command
with `error: <verdict> on <device> <version> (<build>) in …; the emulator log is <path>`.

| Verdict | Means |
| --- | --- |
| `pass` | the command exited 0 |
| `fail(exit N)` | it exited N |
| `fail(spawn error 2)` | there is no such file in the image: wrong path, or `install` not run |
| `crash(signal N, pc 0x…, last frame …)` | it died on signal N; the pc is where the CPU faulted, and the last frame is the host path of the run's `frame.png` |
| `timeout` | still running after `-s` seconds; the runner killed it |
| `boot-blocked(<where>…)` | the command never ran, although the image booted at `install`: the emulator, a process in a crash loop, SpringBoard or the data migration stopped the boot; a guest crash report's reason and a request that never got its reply are named |

`run` prints the command's own standard output and error before the verdict. The evidence stays in
`.cache/emulator/images.noindex/<project>-<hash>/<device>_<build>/run/`: `verdict.json`
(`state`, `guest_seconds`, `host_seconds`, `scale`), `results/test.stdout`, `results/test.stderr`,
`results/reports/` (the guest's crash reports), `emulator.log` and `frame.png`. It is replaced by
the next run of the same device and release: copy what you cite into the project's `.logs/`.

- `xmake emulate -y -d … -r … log [TEXT]` — the last run's output lines, and the emulator's fatal
  CPU faults and signal exits (or every line holding TEXT).
- `xmake emulate -y -d … -r … shot [FILE]` — copies the last frame (default
  `build/<device>_<build>.png`). Look at it; do not describe a frame you have not opened.
- `xmake emulate -y -d … -r … debug /path` — starts the program as the guest's **first process**
  (nothing else boots), stops where it crashes and prints the signal, the frames named by the
  images loaded and the registers; the report is `debug/debug.json` beside `run/`. Use it on a
  `crash(...)` of a program that does not need the rest of the system.

**Time scale.** The emulator is one to two orders of magnitude slower than the device, and the
guest measures its watchdogs in its own seconds. `--scale N` makes one guest second take N host
seconds; the default is 10 and is right for everything except a program that measures time. Such a
target says `set_values("emulate.timing", "strict")` and must be run with `--scale 1` (any other
scale is refused); at 1 the guest's own watchdogs kill long runs. A verdict always states the
scale; `guest_seconds` is the program's own clock.

## 5. Checking an app

**`xmake emulate launch` starts the app the way a tap on the home screen does.** SpringBoard
launches it, so `application:didFinishLaunching…` is reached and the app draws. The command takes
the bundle identifier and the steps to send after it:

```
xmake emulate -y -d iPhone4,1 -r 6.1.3 launch space.kern0x1b.example.demo until-exit > .logs/emulate-launch-iPhone4,1-6.1.3.log 2>&1
```

The steps are `tap X Y`, `drag X1 Y1 X2 Y2` (in points), `home` and `until-exit`. Each step is sent
after the screen has settled, and the run takes a snapshot of each state: `app-0.png` is the app as
it came up, `app-1.png` the state after the first step, and so on. The app's own output is in
`results/app.stdout` and `results/app.stderr`, beside the snapshots in the run's folder (§4). The
run ends with `launched <bundle> as pid <pid> on <device> <version> (<build>) ... N snapshot(s)`.

What a launch proves, and how to word it in `## Progress`:

- **The application came up through SpringBoard.** The launch named the bundle, SpringBoard took
  it, and the app reached `application:didFinishLaunching…`. The snapshot is the evidence: open it
  before describing it.
- **The taps reached it.** A step `tap X Y` was sent and the next snapshot shows what changed.
- **The application survived until it ended.** With `until-exit`, the verdict says `held`, and
  whether the app ended on its own (`exited`) or the run's budget ran out first (`deadline`).

What the launch does not show: the keyboard and the text input, the multitasking and the
backgrounding, the camera, the GPS and the cellular radio. Say so in these words, and check those
on a real device (skill `device`) when the user has one. Never write "the app runs in the
emulator" in `## Progress`; write what was launched, what was sent and what the snapshots show.

A launch is not a device: the emulator draws in software, has no camera, no GPS and no cellular
radio, and its clock is slower than the phone's (§4).

A program that is not an application is run with `run` (§4), and that is the right command for a
probe: `run` starts the program from launchd, as root, with a deadline.

## 6. Record

In `PROJECT.md` `## Progress`, per device and release: the install log path and its `installed`
lines; for each `run`, the command, the verdict line exactly as printed (with the emulated
version, build and scale) and the path of the copied `verdict.json`/frame. Then follow the skill
`package` (or `checks` for more test stands).

## Traps

- `xmake emulate clean` → never while any other project or session on the machine may be
  emulating: it always removes the shared `tmp.noindex` and `cache.noindex` of every project, and
  `--all` every golden image. There is nothing to clean between runs; each run clones afresh.
- Leaving out `-d`/`-r` → the run emulates `apple_minimum` on the first catalog device of the
  architecture, often not the one `PROJECT.md` names; always pass both.
- Reading `fail(spawn error 2)` as an app bug → the path is not in the image; `install` first, and
  pass the guest path of a probe (`/usr/libexec/<name>`), not a host path. Never the app's own
  executable: started by the runner it never becomes an application (§5); `launch` is the command
  for that.
- `kAudioSession…` errors, silent sounds → no audio server runs for `run` (§1); record audio as
  unchecked, not as the app's fault.
- A run with `--scale 1` "to be realistic" → the guest's watchdogs expire (SpringBoard is lost to
  a mediaserverd timeout); keep 10 unless the target is `emulate.timing` strict.
- Treating a pair that does not boot (the first `install` stops with `did not get past`, or a run
  says `boot-blocked`) as the app's failure → it is the emulator's coverage; report it as "not
  checkable here".
- Two commands on the same project, device and release at once → the second waits for the first
  (per-image lock); several projects may emulate at once, each boot takes one of the machine's
  slots (`min(cores/3, RAM/5 GB)`) and waits for a free one.
- Results written with `NSLog` → they do reach what `run` prints, through standard error
  (`results/test.stderr`, found by `log`; measured on iPhone 4S 6.1.3), but after the standard
  output and with a timestamp prefix; write the `ok`/`FAIL` lines with `printf` and
  `fflush(stdout)` so they stay in order and survive a crash.
- Launching the app some other way (a hand-written LaunchDaemon for it, a launcher copied into the
  image, an edited image) → not a check of the app as a user starts it; `launch` is the native
  path, because SpringBoard itself launches the app (§5). Say so.
