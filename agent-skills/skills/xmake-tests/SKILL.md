---
name: xmake-tests
description: Reference for testing an old-iOS app built with Charon, and what xmake test (xmake 3.1.1) can and cannot do for it — xmake test runs each case on the Mac, so it cannot run the app or anything built by Charon's rules; it can run host tests of the app's platform-independent logic in a target built for macOS in the same project. Covers the host-test target, add_tests and its options (whole-output patterns, trim_output, plain, groups, should_fail, runenvs, run_timeout), reading the report, and where the on-target tests live instead (probes run in the emulator or on the device). Use when adding tests, deciding where a test runs, or reading an xmake test failure.
---

Derived from the `xmake-tests` skill of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# Tests for an app for old iOS

`xmake test` builds every target that declares a test case (a `set_default(false)` target too) and
then **runs each case's program on the Mac**. An app or program built by Charon's rules is for the
device; the Mac cannot run it. So there are two kinds of test, run by two commands:

| What is tested | Built as | Run by | Result |
| --- | --- | --- | --- |
| logic that needs no iOS framework (parsing, arithmetic, model code in C, C++ or Foundation-only Objective-C) | a target for macOS in the same project | `xmake test` | the report: `N% tests passed, M test(s) failed out of K, …` |
| the code on the release it ships for, against that release's own libraries | a probe with Charon's `daemon` rule | `xmake emulate run`, or `xmake device run` on a real device | the verdict: `pass`, `fail(exit N)`, `crash(…)`, `timeout` |

A host test that passes proves the logic on macOS only: macOS's Foundation and the Mac's compiler
are not the release's libraries. Read `PROJECT.md` first: the releases to check decide where the
on-target tests run.

## 1. The host-test target

Keep the logic the app and the tests share in its own files (for example `logic/*.c`), compiled
into the app's target and into a host-test target. The host-test target differs from every other
target of the project in three lines:

- `set_plat("macosx")` and `set_arch("arm64")` (the Mac's own architecture, `uname -m`) — it is
  built for the Mac, with the Mac's own toolchain, into `build/macosx/arm64/<mode>/`;
- `set_default(false)` — a bare `xmake` does not build it; `xmake test` does;
- no Charon rule and no `add_packages`: the packages of this project are built for the device.

Then its `add_files` (the test's `main` and the shared sources), `add_includedirs`, and
`add_tests("default")`. Objective-C tests add `add_mflags("-fobjc-arc")` and
`add_ldflags("-fobjc-arc")` like any Objective-C target. Nothing of this target goes into the app
or its package.

The test program prints one line per check and exits with the number of failures; a non-zero
exit fails the case, so it needs no output pattern.

```
xmake test -y -v > .logs/test.log 2>&1
xmake test -y -v logic_host_test/default > .logs/test-one.log 2>&1
xmake test -y -v -g host > .logs/test-host.log 2>&1      # add_tests("default", {group = "host"})
```

Options stand before the case names: those are a list, and an option after them is read as one
more name.

How to know it worked: the log has one line per case, `[100%]: logic_host_test/default … passed
0.012s`, and ends with `100% tests passed, 0 test(s) failed out of N, spent …`. A failed case
says `failed` on its line; the reason (`errors: run <target>/<case> failed, exit code: <n>`) is
printed only with `-v` or `-D`.

## 2. add_tests options

- `runargs`, `rundir`, `runenvs = {NAME = "value"}` (replaces the target's run environment),
  `run_timeout` (milliseconds).
- `group = "<name>"`, selected with `xmake test -g <name>`.
- `pass_outputs` / `fail_outputs`: a **Lua pattern matched against the whole standard output**,
  anchored at both ends — not a substring, and standard error is not read. `pass_outputs =
  "0 failures"` fails on the output `logic_test: 0 failures\n`; write
  `{trim_output = true, pass_outputs = ".*: 0 failures"}`, or `plain = true` for an exact string.
  An exit status is simpler and harder to fool.
- `should_fail = true`: the case passes only if the run fails. Use it for the negative control:
  the same program run so that it must fail (for example with `runenvs` that make it read a broken
  input) proves the test can fail at all. The report then says `… 0 test(s) failed, 1 expected
  failure(s) out of N, …`, and a control that passes is reported as an `unexpected pass`.
- `build_should_pass` / `build_should_fail`: the case is the build itself; nothing is run.

## 3. Tests on the target release

The on-target test is a probe: a small program with Charon's `daemon` rule, its own control file,
`-fobjc-arc` on compile and link, `ok`/`FAIL` lines with `printf` and `fflush`, and a negative
control — the skill `checks` says how to write it. It runs in the emulator with
`xmake emulate -y -d <device> -r <release> run /usr/libexec/<probe>` (skill `emulate`: the
device, the release, the cost of a run, what a verdict proves) and on the device with
`xmake device run` (skill `device`). The verdict line is the result; record it as those skills say.

Do not declare `add_tests` on the app or on a probe: `xmake test` builds it (Charon's checks run)
and then tries to start a device binary on the Mac, and the case fails (a daemon probe at the pin:
`errors: run <probe>/default failed, exit code: 255`). Charon 0.8.10 has no
command that runs on-target programs as `xmake test` cases.

## 4. Keep the emulator out of xmake test

xmake lets a target or a rule replace a case's run with its own `on_test` script, and such a
script could call `xmake emulate run`. Do not: run the emulator as its own command (§3), one at
a time, with its own log. Inside a test case the run's log, verdict line and evidence folder are
out of sight, and a stopped `xmake test` is not known to stop what its script started. Tell the
user that on-target tests run as separate emulator or device commands, not as one `xmake test`.

## Traps

- `add_tests` on the app target to "test the app" → host tests for the logic (§1) and a probe for
  the release (§3). Reason: `xmake test` runs the file on the Mac, which cannot run a device binary.
- A host test that passes, reported as "works on iOS 6" → report it as a host result; the
  on-target verdict is the evidence for the release.
- The host-test target given a Charon rule or the project's packages, or the app's target given
  `set_plat("macosx")` → keep them apart. Reason: Charon's rules and packages build for the
  device; the app is never built for macOS.
- `pass_outputs = "OK"` expecting a substring match → a whole-output pattern with `trim_output`,
  or the exit status. Reason: xmake matches `^pattern$` against the entire standard output.
- `xmake test <case> -y` → `xmake test -y <case>`. Reason: the case names are a list, and `-y`
  after them is taken as one more case name.
- A test suite without a case that must fail → add a `should_fail` control. Reason: a suite that
  cannot fail proves nothing.
