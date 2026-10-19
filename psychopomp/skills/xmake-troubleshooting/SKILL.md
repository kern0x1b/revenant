---
name: xmake-troubleshooting
description: Diagnose xmake 3.1.1 itself when building an old-iOS app with Charon misbehaves — decide which layer stopped (a package install, the addon, the toolchain's architecture check, Charon's checks, the run), read a failed package's install.txt, find which process holds the project or package lock when a command waits in silence, trace a hanging command with XMAKE_PROFILE=stuck, recognise the addon not being installed or not the pinned one, and collect what a report to Charon needs — fixing the cause (xmake f with every choice, the right rule, the right flags) instead of forcing, deleting the store or disabling a check. Use when xmake does something you cannot explain; for a refusal by Charon's own checks the skill build comes first.
---

Derived from the `xmake-troubleshooting` skill of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# When xmake misbehaves

Work from the cheapest look to the most invasive, and fix the cause where it is. Never a fix:
forcing a package, deleting from the package store, a private store, or silencing or waiving a
Charon check to get a green build (the rules for every step, skill `psychopomp`). Read `PROJECT.md`
first, and log every command to a file under `.logs/` so the evidence stays.

## 1. See what it is doing

```
XMAKE_COLORTERM=nocolor xmake -y -v > .logs/build-v.log 2>&1      # every tool command it runs
XMAKE_COLORTERM=nocolor xmake -y -vD > .logs/build-vD.log 2>&1    # plus a Lua traceback on error
xmake f -vD -p iphoneos -a armv7 -y > .logs/configure-vD.log 2>&1
```

- The traceback names the file that raised: a path under `~/.xmake/addons/charon/<version>/` is
  Charon (the version in it is the addon actually in use); a path under xmake's own install is
  xmake.
- `xmake show` prints `plat`, `arch` and `mode` in force; `xmake show -t <Name>` prints the target's
  rules, files, compiler and linker with their flags.
- A package that fails prints `=> install <name> <version> .. failed`, then up to 17 lines of its
  errors, `if you want to get more verbose errors, please see:` and the path of its log,
  `~/.xmake/cache/packages/<yymm>/<l>/<name>/<version>/installdir.failed/logs/install.txt`. Read
  that file. With `-D` xmake prints the whole error instead of the path.

## 2. Decide which layer stopped

| Where it stops | What it is | Next |
| --- | --- | --- |
| `xmake f` with `install … failed` | a package build | its `install.txt`; skill `xmake-packages` |
| `rule(@addon/charon/…) not found!` or `includes(@addon/charon/…) not found!` | the addon is not installed | §4 |
| `apple_minimum … is older than …` / `… is newer than …` | architecture and release disagree | skill `xmake-toolchains` |
| `target(<Name>) builds for apple-ios …`, `imports:`, `… is not what the platform runs: …`, `a link input of <Name> was not built for this target: …` | Charon's checks | skill `build` |
| the program dies on the device or in the emulator | the run | skills `emulate`, `device`; `Bad system call: 12` is the skill `build`'s |
| a build for another architecture or mode than asked, a removed flag still there | stale configuration | skill `xmake-basics`, step 3 |

## 3. It waits in silence

Look at processes, not at the log's last line: a long step prints nothing until it ends.

```
pgrep -fl xmake
pgrep -fl 'cmake|ninja|clang'
lsof .xmake/macosx/arm64/project.lock
```

- **Another xmake holds the project.** A configure, build (and so `xmake deb`), test or clean
  holds `.xmake/macosx/arm64/project.lock` (the host's platform and architecture, whatever the
  target) while it works.
  A second one waits for it without a word: `the current project is being accessed by other
  processes, please wait!` is printed only with `-D`. `lsof` on the lock lists the xmake
  processes that have it open, the holder and any that wait; `ps -o etime= -p <pid>` shows which
  started first. Let it finish, or stop the one you started and no longer need; never delete the
  lock.
- **Another xmake installs the same package.** Each package being installed holds a
  `package.lock` in its folder under `~/.xmake/cache/packages/<yymm>/<l>/<name>/<version>/`; a
  second install waits and says `package(<name>) is being accessed by other processes, please
  wait!`. Projects on other packages do not block.
- **The toolchain is being built, or a prompt waits for `-y`, or a killed fetch left
  `.git/index.lock`:** the skills `install` (step 6, traps) and `build` ("Two xmake processes",
  "A prompt waiting for -y") say what each looks like and what to do.
- **An emulator run waiting for the machine.** `xmake emulate run` first prints `waiting for the
  machine to quiet down before emulating (load <x> on <n> cores)` and waits up to two minutes,
  then says `the machine is still busy after <n> s; starting anyway`. Expected on a busy Mac.
- **Still unexplained.** Run the same command again, alone, as
  `XMAKE_PROFILE=stuck XMAKE_COLORTERM=nocolor xmake -y -v > .logs/stuck.log 2>&1`: every process
  xmake starts is printed as `<subprocess: <name>>: <program> <arguments>`. The last such line
  names what it is waiting for.

## 4. The addon is missing or not the pinned one

The rules, the toolchain and the checks come from `~/.xmake/addons/charon/<version>/`. A project
whose addon lock is missing or does not match installs the addon when it loads and says so:
`note: this project needs the addons(charon v<X>), installing them ..`. When a rule or include is
still `not found!`, that install did not happen: read the configure log for its error (a network
failure, a tag that does not exist) and run `xmake f -y` again once it is fixed. Do not install
the addon by hand with `xmake addon`: the project installs the version it pins.

When the lock or `xmake addon --list` names another version than the pin: the skill `build` ("The
addon in use is not the one pinned") and the first trap of the skill `install`. Stop and tell the
user; do not edit the lock.

## 5. Reporting a problem to Charon

When the cause is in Charon or xmake and not in the project, collect: `xmake --version`, the tag
pair from `xmake.lua`, both lock files, the smallest `xmake.lua` that shows it, and the `-vD` log.
Tell the user where the problem is and what you collected; do not work around it in the project.

## Traps

- `xmake require --force` or deleting under `~/.xmake/packages` because "something is cached" →
  `xmake f -c` with every choice given (skill `xmake-basics`, step 3). Reason: a changed input is
  already a new install path, and the store is shared.
- Waiting on a silent command without looking → `pgrep` and `lsof` on the lock. Reason: the
  project lock's wait message is printed only with `-D`.
- Starting a second `xmake` in the same project to "see if it is still going" → `pgrep`. Reason:
  it waits on the first one's lock and adds nothing.
- Waiving a check (`charon.waive.<check>`) or dropping `-fobjc-arc` to get past a refusal → fix
  what the check names (skill `build`). Reason: the check reports what fails on the device.
- `xmake addon --install charon` to fix `not found!` → let the project install its pin (§4).
  Reason: an install makes the version it installs the machine's active one, which other
  projects' locks are then written from (skill `install`, first trap).
- Reading only `install … failed` → read `install.txt` (or run with `-D`). Reason: the first lines
  shown are cut at 17.
