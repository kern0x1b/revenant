---
name: checks
description: Prove that the app's code does what it should on the chosen iOS release by running small programs of your own — probes (a command-line program, no UIKit) in the emulator and on the device, and test stands (a second small app) on the user's device — each built through Charon with -fobjc-arc, printing ok/FAIL lines with printf and fflush, with a negative control that shows the check can fail. Use after the skill build, beside the skill emulate, whenever an API newer than the lowest release, a backport, a guard with respondsToSelector: or #available, threading or persistence needs evidence, or when the user asks to test, verify or check the app.
---

# Probes and test stands

A build that links proves the imports resolve; it does not prove the code does the right thing on
iOS 6. A check does: a small program that exercises one piece of the app's code on the chosen
release, prints one line per expectation, and exits with the number of failures. There are two
shapes:

- a **probe** — a command-line program (Charon's `daemon` rule), no `UIApplicationMain`. It runs in
  the emulator (`xmake emulate run`) and on the device (`xmake device run`). Use it for everything
  that does not need a running application: Foundation, data, parsing, networking code, backports
  of non-UI APIs, the availability guards.
- a **test stand** — a second, small application (Charon's `app` rule) for what needs a running
  `UIApplication`: views, controllers, layout, gestures, text. A UIKit object made outside an
  application can trap. With Charon 0.8.10 the emulator cannot launch an app through SpringBoard
  (its `run` starts the executable directly, and it never reaches
  `application:didFinishLaunchingWithOptions:`), so a test stand runs on the user's device only
  (skill `device`); without a device, say that the UI is unchecked.

Read `PROJECT.md` first: `apple_minimum`, the releases and devices to check, the backports, and what
the app does. Write the checks, not the app's features, in these targets: the check calls the app's
own code (the same source files or a static library both link), never a copy of it.

## 1. Decide what each check expects

For every item below that the app has, write the expectation down before running anything:

- each API introduced after `apple_minimum` and how it is reached — a backport, a
  `respondsToSelector:` / `#available` guard, or the older API;
- each backport the app links (`PROJECT.md` lists them): the answer the newer iOS gives;
- persistence (a value written, the process ended, the value read back), date and number
  formatting, parsing of what the server sends;
- anything done on another thread and delivered back.

The expected value comes from outside the code under test: Apple's documentation, the behaviour of
a newer iOS or of macOS for the same call, the server's real answer saved to a file. An expectation
copied from what the code printed on its first run proves nothing.

## 2. The probe target

In the project's `xmake.lua`, one target per probe, beside the app's target:

- `add_rules("@addon/charon/daemon")` — it installs to `/usr/libexec/<target name>`. Never build a
  probe with the host's `cc` or `clang`: the binary is for macOS and dies on the device with
  `Bad system call: 12`.
- `add_mflags("-fobjc-arc")` **and** `add_ldflags("-fobjc-arc")` (`add_mxflags` too for `.mm`). On the link the flag makes clang
  force-load arclite, which carries the ARC entry points into the image below iOS 5 and the
  collection subscripting methods below iOS 6.
- The same `add_packages(...)` as the app, so it links the backports the app does.
- Its own control file, so it is a package of its own and never ends up in the app's `.deb`:
  `set_values("charon.control", "packaging/<probe>-control")`, holding only `Package:` (e.g. the
  app's package name plus `.probe`), `Architecture: iphoneos-arm`, `Maintainer:` and
  `Description:`. No `Version:` — the build writes it from `set_version`.

The program:

- One line per expectation on standard output: `ok <name>` or `FAIL <name>: <what was seen>`,
  `printf` then `fflush(stdout)` after every line, so a crash loses nothing already printed.
- A last line `checks=<N> failures=<M>`, and `return failures` from `main`.
- A crash is a result too: install an uncaught-exception handler
  (`NSSetUncaughtExceptionHandler`) that prints `FAIL uncaught <name>: <reason>` and flushes.
- Where the environment does not answer (in the emulator a probe starts before the system daemons,
  so audio has no server; location and motion are not checked there either),
  print `skip <name>: <reason>` instead of a verdict — never an `ok`.

How to know it worked: `xmake -y -v > .logs/build.log 2>&1` has `build ok`, and the probe's link
line is followed by `imports: every non-weak import ... resolves`.

## 3. Run it in the emulator

The skill `emulate` covers the emulator itself (setup, devices, releases, limits). For a probe:

```
xmake emulate -y -d <device> -r <release> install
xmake emulate -y -d <device> -r <release> run /usr/libexec/<probe> [arguments] > .logs/probe-<release>.log 2>&1
xmake emulate -y -d <device> -r <release> log FAIL
```

`install` writes every package of the project (the app's, its dependencies', each probe's) and
installs them into the emulated image; `run` starts the probe with a 60-second deadline (`-s`) and
prints its output, then the verdict. The exit status is the verdict:

| Verdict | Means |
| --- | --- |
| `pass` | exited 0: no failure |
| `fail(exit N)` | N checks failed; the `FAIL` lines say which |
| `fail(spawn error 2)` | the probe is not in the image: `install` first |
| `crash(signal N, pc ...)` | read the frames with `xmake emulate -y -d <device> -r <release> debug /usr/libexec/<probe>` (it takes the path only, no arguments) |
| `timeout` | it waited past `-s`: a deadlock or a wait with no timeout (step 5) |
| `boot-blocked(...)` | the emulated system never reached the probe; not the probe's fault |

Run it on every release `PROJECT.md` lists that the emulator boots. Keep the log under `.logs/`.

## 4. The negative control

A check that has never failed proves nothing. For each probe, run once with one expectation made
wrong on purpose — an argument such as `--negative` that flips a single expectation — and see it
fail:

```
xmake emulate -y -d <device> -r <release> run /usr/libexec/<probe> --negative > .logs/probe-<release>-negative.log 2>&1
```

It must print `FAIL <that name>: ...`, end with `checks=<N> failures=1`, and the verdict must be
`fail(exit 1)`. For an availability guard,
the control is the lowest release itself: the guarded API must be seen absent there (the guard's
`else` branch runs), and present on a release that has it.

## 5. Waiting for an answer

- Never wait on the main queue from the main queue: `dispatch_sync(dispatch_get_main_queue(), ...)`
  on the main thread deadlocks at once.
- Never block the main thread waiting for something that answers on the main queue (many completion
  handlers do): the answer is queued behind the wait. Start the work, then wait **off** the main
  thread — `dispatch_async` to a global queue, and wait there.
- Off the main thread, wait on a `dispatch_semaphore_t` with a timeout
  (`dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))`), and treat a
  timeout as `FAIL`. Never spin `CFRunLoopRunInMode` there: on a thread whose run loop has no source
  it returns at once, and the wait becomes a busy loop or no wait at all.
- In a test stand, schedule the next step with an `NSTimer` or
  `performSelector:withObject:afterDelay:`, not with `dispatch_async` to the main queue from a block
  already running there: the main queue is serial, and the queued block waits behind the running one.
- A probe has no application run loop: an API that delivers its answer on the main queue needs the
  probe's main thread to run one, ended by the probe itself when the answer came or the time ran out.

## 6. The test stand

A second app target in the same project: `add_rules("@addon/charon/app")`, its own bundle identifier
(the app's plus `.stand`), its own control file, `-fobjc-arc` on compile and link, the app's own
sources for the part under test. It builds its screens, drives them through the app's code, and
reports like a probe.

- **Its report is a file, not `NSLog`.** The user starts the stand by tapping its icon. Its `NSLog`
  lines do reach the device's system log (measured on iPhone 4S 6.1.3), but that log is read over
  USB, only while it streams, and among every other app's lines; a file holds the stand's lines
  alone, in order, and is read over SSH whenever you look. At start, reopen
  standard output onto a file the `mobile` user can write — `freopen(path, "w", stdout)` then
  `setvbuf(stdout, NULL, _IOLBF, 0)` — and print with `printf` + `fflush` as a probe does.
- **The file is written by `mobile`.** An app runs as `mobile`, SSH as `root`; a directory made over
  SSH belongs to root and the app cannot write into it. Pick a path under `/var/mobile`, create it
  as mobile and check it (skill `device`, "root and mobile").
- **It ends itself.** After the last check it prints `checks=<N> failures=<M>` and a line `done`; the
  file without `done` means it stopped early (read the crash report, skill `device`).
- It runs on the user's device: `xmake device -y install`, the user taps the stand's icon, then
  `xmake device run "cat <path>" > .logs/stand-<release>.log`. The negative control is the same as a
  probe's: one run with one expectation made wrong, seen as `FAIL`.

## 7. Keep checks out of what is shipped

- `xmake deb <app target>` writes only the app's package (and its dependencies); plain `xmake deb`
  also writes each probe's and stand's package into `build/`. Never publish those.
- Remove the probes and stands from the user's device when you are done (skill `device`, uninstall).

## 8. Record

In `PROJECT.md` `## Progress`: under `emulator`, each probe with its release, device, verdict line
and log path, and the negative control's `fail(exit 1)` line; under `device`, each test stand with
its log path and its `checks=` line. A check that could not run (no device, a release the emulator
does not boot) is written down as unchecked, with the reason.

## Traps

- A probe compiled with the host's compiler → `Bad system call: 12` on the device; build it with
  Charon's `daemon` rule.
- `-fobjc-arc` on the compile only → below iOS 5 the build's import check refuses the ARC entry
  points (`should carry it from arclite`); from 6.0 the build is green without it and the flag's
  absence goes unseen — put it on the link anyway, the lowest release can move.
- Output without `fflush` → a crash loses the lines before it, and the last line seen is not the
  last check that ran.
- `NSLog` as the report → write a file with `printf` + `fflush`; read it with `xmake device run "cat ..."`.
- Waiting on the main queue from the main thread → deadlock, seen as `timeout`; wait off it, on a
  semaphore with a timeout.
- `CFRunLoopRunInMode` on a background thread → returns at once; use a semaphore.
- A check with no negative control → it may be unable to fail; flip one expectation once.
- An expectation taken from the code's own first output → the check agrees with the bug; take it
  from documentation, a newer system or the real server.
- `skip` counted as `ok` → where the emulator does not answer (audio has no server there; location
  and motion are unchecked), the check needs the device.
- A UIKit check in the emulator → the app never reaches `didFinishLaunching` there with Charon
  0.8.10; run it as a test stand on the device, or record it as unchecked.
- `xmake check` taken for this → it runs the host-side scripts a project declares with Charon's
  `check` rule (lint, pre-commit), not programs on iOS.
