---
name: xmake-basics
description: Reference for how an old-iOS app project drives xmake 3.1.1 with the Charon addon — where xmake keeps the configuration, the build and the packages, which Charon rule gives a target its kind and why a device target without one is wrong, set_default and add_deps, build modes (mode.debug, mode.release) and the strip policy Charon's checks need, what xmake f keeps and forgets between runs (-c, a failed configure, options given again), options before a positional argument, what xmake run cannot do, the commands the addon adds, and the environment variables that matter (XMAKE_COLORTERM, CHARON_HOME, and why XMAKE_GLOBALDIR stays unset). Use when writing or reading an xmake.lua, when a configure or build does something unexpected with platform, architecture or mode, or before running an xmake command whose effect you do not know.
---

Derived from the `xmake-basics`, `xmake-targets`, `xmake-commands` and `xmake-env-vars` skills of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# xmake for an old-iOS app

xmake reads `xmake.lua` in the project directory, keeps the project's configuration under
`.xmake/macosx/arm64/` (the host's platform and architecture, not the target's), builds into
`build/<plat>/<arch>/<mode>/`, and installs packages into a store shared by every project on the
machine (`~/.xmake/packages`). Charon is an xmake addon, installed under
`~/.xmake/addons/charon/<version>/`: it brings the `apple-ios` toolchain, the rules that make a
target an app, daemon, tweak or library, the checks every binary is held to, and commands such as
`xmake deb` and `xmake emulate`. Read `PROJECT.md` first.

The project-wide lines of `xmake.lua` and their order are the skill `install`'s (step 4); the app
target's lines are the skill `project`'s (step 3); the build loop and its checks are the skill
`build`'s. This skill explains the xmake underneath them.

## 1. Targets

- A target's kind comes from its Charon rule: `app` and `daemon` make an executable, `library` and
  `tweak` a shared library. Do not also call `set_kind`. The rule binds the `apple-ios` toolchain
  and runs Charon's checks after the link.
- **Every target that runs on the device carries a Charon rule.** A plain `set_kind("binary")`
  target has no Charon toolchain: on `iphoneos` xmake gives it its own Xcode toolchain, which on a
  Mac with only the Command Line Tools finds no iPhoneOS SDK (`checking for Xcode SDK ... no` in
  the configure log). Building it runs the Command Line Tools' `clang` with an empty `-isysroot`
  and stops at `fatal error: 'stdio.h' file not found`; none of Charon's checks would run on it.
- `set_default(false)` keeps a target (a probe, a test program) out of a bare `xmake`; name it to
  build it: `xmake build -y -v <target>`.
- `add_deps("<target>")` builds another target of the project first and links it.
- `is_plat("iphoneos")`, `is_arch("armv7")` branch the description on the configuration.
- A project inside another checkout: run `xmake -P .` (skill `build`, "Other refusals").
- `xmake -P <dir>` from another folder builds into `build/` (and configures into `.xmake/`) of the
  folder you are in, not of `<dir>` (xmake 3.1.1 `core/project/config.lua:164-168`). Run xmake
  from the project folder; `-P .` there changes nothing.

## 2. Modes

Without mode rules, `xmake f -m debug` changes only the output folder: xmake adds no `-O` and no
`-g` to the project's own files. The packages are optimised anyway (`-O3`, from Charon's toolchain
for packages). To compile the app's code with optimisation, add the two rules and the policy:

```
add_rules("mode.debug", "mode.release")
set_policy("build.release.strip", false)
```

- `release` is the default mode. With the rules it compiles with `-Oz` and `-fvisibility=hidden`
  (not for a shared-library target), and adds `-DNDEBUG` to C and C++ files only, not to `.m` or
  `.mm`. `-m debug` compiles with `-O0 -g`.
- The policy belongs with `mode.release`: that rule otherwise links with `-Wl,-x -Wl,-dead_strip`,
  which removes the local symbols. Charon's link check needs those names to check each code
  pointer's mode, and refuses the binary when none of its code pointers is named any more:
  `… is not what the platform runs: none of its N rebased code pointers names a function in its
  symbol table, so no pointer's mode could be checked; it arrived stripped, and the check has to
  see it before strip`. Charon strips each binary itself after that check, when it assembles the
  bundle (`charon.strip`, default `-x`).
- The mode is part of every path: a debug build is `build/iphoneos/<arch>/debug/<Name>.app`.

How to know it worked: `xmake -r -y -v > .logs/build.log 2>&1`; the compile lines of the app's
own files (`grep -- ' -c ' .logs/build.log`) carry `-Oz` in release and `-O0` in debug, and the
log has `build ok`.

## 3. What xmake f keeps and forgets

```
xmake f -p iphoneos -a armv7 -y > .logs/configure.log 2>&1
```

- **An `xmake f` given options of its own forgets the ones earlier runs were given**, and so does
  `xmake f -c`: whatever this line does not name falls back to the project's defaults
  (`set_defaultplat`, `set_defaultarchs`, the default mode `release`). After
  `xmake f -a armv7s -y`, a later `xmake f -m debug -y` or `xmake f -c -y` builds armv7 again.
  Give every choice on every `xmake f`: `xmake f -c -p iphoneos -a armv7 -m debug -y`. A bare
  `xmake f -y` keeps the earlier ones.
- **A failed `xmake f` saves nothing.** The next `xmake` builds with the configuration saved
  before it. Read the end of the configure log, then `xmake show` (`plat:`, `arch:`, `mode:`)
  before trusting a build.
- Edits to `xmake.lua` or a file it includes are picked up by the next `xmake`, which configures
  again by itself.
- `-c` drops the cached resolution too; after a change to `add_requires` or a package's configs
  use `xmake f -c` with every choice given (skill `build`, step 1).

## 4. Options before a positional argument

Put every option right after the command: `xmake deb -y -v <target>`, `xmake build -y -v
<target>`. After the first positional argument xmake reads everything as positional:

- a command that takes one argument (`xmake deb`) stops with `error: invalid argument: -y`;
- a command that takes a list (`xmake build`, `xmake run`, `xmake device`, `xmake emulate`) takes
  the option as one more argument, which is worse: `xmake build <target> -y` asks for a target
  named `-y`, and `xmake run <target> -y` hands `-y` to the program.

## 5. What runs where

The build output is for the device. `xmake run <Name>` starts it on the Mac, which cannot run an
armv7 binary; it stops with `error: execv(<file> ) failed(<n>), unknown reason`. Check the app in
the emulator (skill `emulate`) or on the device (skill `device`); test logic on the Mac as the
skill `xmake-tests` says.

Commands the Charon addon adds, and the skill for each:

| Command | Skill |
| --- | --- |
| `xmake firmware` (`fetch`, `rootfs`, `list`, …) | `firmware` |
| `xmake deb` | `package` |
| `xmake emulate` (`install`, `run`, `debug`, `log`, `shot`) | `emulate`, `checks` |
| `xmake device` (`install`, `uninstall`, `run`, `log`, …) | `device` |
| `xmake where <package>` — the install folder of a package the project requires, by name or alias | `xmake-packages` |
| `xmake borrow` | `install` |
| `xmake check` — host-side scripts, not programs on iOS | `checks` |

## 6. Environment variables

`xmake show -l envs` lists the `XMAKE_*` variables xmake documents, with their current values.

- `XMAKE_COLORTERM=nocolor` — plain text in logs you will read or `grep`.
- `CHARON_HOME` — where Charon keeps the release libraries, firmware, root filesystems, emulator
  images and device state (default `~/.charon`). Set it only to move that data to another disk,
  and then the same way for every command.
- `XMAKE_PROFILE=stuck` — traces what a hanging command runs (skill `xmake-troubleshooting`).
- `XMAKE_GLOBALDIR`, `XMAKE_PKG_INSTALLDIR`, `XMAKE_PKG_CACHEDIR` — **leave unset.** They move the
  package store (`XMAKE_GLOBALDIR` the addons as well). A store of its own starts empty and builds
  Charon's compiler from source again (an hour or more, more for Swift); the shared store already
  has what the project needs.
- `XMAKE_RCFILES` — not needed; what the project needs belongs in its `xmake.lua`, where the next
  reader sees it.

## Traps

- A device binary as a plain `set_kind("binary")` target → the `daemon` (or `app`) rule. Reason:
  without a Charon rule it is built by xmake's Xcode toolchain, without Charon's SDK and checks.
- `mode.release` without `set_policy("build.release.strip", false)` → add the policy. Reason: the
  release link strips the names Charon's check reads.
- `xmake f -m debug -y` (or `-c -y`) after choosing an architecture on an earlier line → give
  `-p` and `-a` again. Reason: options given anew replace the earlier set; the rest fall back to
  the project defaults.
- `xmake <command> <target> -y` → `xmake <command> -y <target>`. Reason: after a positional
  argument xmake reads options as arguments.
- `XMAKE_GLOBALDIR` pointed at a fresh directory for a "clean" build → never. Reason: a changed
  package is already a new install path; a private store only rebuilds the compiler from source.
