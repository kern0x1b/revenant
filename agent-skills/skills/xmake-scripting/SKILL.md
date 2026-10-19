---
name: xmake-scripting
description: Reference for Lua scripts in the xmake.lua of an old-iOS project built with Charon — description scope against script scope, which hook to use (on_load, on_config, before_build, after_link, after_build, a task of your own) and how it combines with Charon's rules, import() of xmake modules, your own modules and the Charon modules a project may use, os.* and path.* for host tools and files, and the traps (a script that runs xmake again must pass the task first and must never start a build, configure or test of its own project from inside one; never an emulator run inside xmake test; never touch the shared package store or Charon's data). Use before writing any on_*/before_*/after_* function, task(), import() or os.* call in an old-iOS project, or when a script hangs, runs too often or its output never appears.
---

Derived from the `xmake-scripting` and `xmake-script-modules` skills of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# Scripts in an old-iOS project

Most of what a project needs is a line, not a script: Charon's values place resources, plist keys,
libraries and package contents (skill `xmake-rules`). Write a script only for what no value
covers, and keep it on the Mac: it prepares files and runs host tools. It never builds for the
device by itself, never drives the emulator or a device, and never touches the shared package
store. Read `PROJECT.md` first, and put everything a script writes under the project (`build/`,
`.logs/`).

## 1. Two scopes

- **Description scope**: the top level of `xmake.lua` and the body of `target(...)`, `rule(...)`,
  `task(...)`. It runs every time xmake reads the file, which is every command. It declares:
  `set_*`, `add_*`, `is_plat`, `get_config`, `includes`. It has no side effects. Charon's own
  include runs here (`v0.8.10:includes/apple-ios/xmake.lua:15-37`), so its
  `note: the <arch> slice is built for iOS …` line is printed each time the file is read for a slice
  whose architecture first ran a later release than `apple_minimum`.
- **Script scope**: the functions given to `on_*`, `before_*` and `after_*` of a target, rule,
  task or package, and every module loaded with `import`. Only here do `os.*` side effects,
  `target:*` calls and `import` belong.

A process started, a file written or the network reached at the top level happens on every
`xmake` command. Move it into a hook.

## 2. Which hook

The hooks a target may define in xmake 3.1.1 are listed in `core/project/target.lua:3167-3240`.
With Charon's rules on the target (skill `xmake-rules` §3 has the full order):

| You want | Hook | Note |
| --- | --- | --- |
| a value computed from a file (a define, a version string) | `on_load` or `on_config`, `target:add(...)` | runs after the rules' `on_load`: add, do not replace what they set |
| a generated source compiled into the target | a rule of your own | skill `xmake-rules` §4 |
| a host tool run before compiling | `before_build` | through `os.vrunv` (§4) |
| a report on the linked binary (size, a symbol list) | `after_link` | Charon's checks run in the rules' `after_link` beside it |
| something on the finished `<Name>.app` | after `xmake` returns, not in a hook | see below |

Never `on_build`, `on_link` or `on_install` on a target with a Charon rule. xmake then skips the
rules' own script of that stage, and with it Charon's placement, stripping and signing.

The target's `after_build` and the `app` rule's `after_build` run as one stage with no order
between them. xmake orders rule scripts only through a rule's `add_orders`
(`modules/private/utils/rule.lua`, `build_orders_in_jobgraph`). The rule deletes and rewrites
`<Name>.app` there (`v0.8.10:modules/apple/platform.lua:437-440`). A hook of yours that reads the
bundle may see it half-written, and a file it adds is gone. Use the bundle after `xmake`
returns, in a command of your own.

## 3. import

- xmake's modules: `import("core.project.project")`, `import("core.base.option")`,
  `import("core.base.task")`, `import("lib.detect.find_tool")`. The options are `alias`,
  `rootdir`, `try`, `anonymous`, `inherit` and `nocache`
  (`core/sandbox/modules/import/core/sandbox/module.lua:473-499`).
- Your own modules: a `.lua` file with top-level functions; a name starting with `_` stays
  private, and a `main` function is called when the module itself is called. Put it beside
  `xmake.lua` (e.g. `scripts/stamp.lua`) and `import("scripts.stamp")` from a hook. The directory
  of the importing script is searched first.
- Charon's modules are imported with the `@addon.` prefix (`module.lua:519-524`). A project uses
  only those Charon's README documents for it: `@addon.charon.apple.cmake`, `.sources`,
  `.install` and `.envs` in a package recipe (skill `xmake-packages`), and
  `@addon.charon.apple.compat` (`v0.8.10:README.md:421-450,600-603`). The rest (`apple.platform`,
  `apple.dyld`, `apple.macho`, …) is Charon's inside. Never import it to run, skip or re-run a
  check yourself.

How to know it worked: `xmake -vD -y > .logs/build-vD.log 2>&1` prints a traceback naming your
file and line if an import or a call fails (skill `xmake-troubleshooting`).

## 4. os.*, path.* and io.* in this project

- Run a host tool with the list form: `os.vrunv(program, {args...})` (no shell parsing; the command
  line is printed only with `-v`, `core/sandbox/modules/os.lua:286-293`), `os.iorunv` to capture its
  output, `os.execv` to stream it. Charon's own scripts use the same (`v0.8.10:rules/apple-ios/xmake.lua:4`,
  `rules/swift/xmake.lua:183`). In the list form each argument reaches the program as it is.
  Prefer it to the string forms (`os.exec("… " .. path)`), whose command line is parsed again.
- Find a host tool with `lib.detect.find_tool`. Never run a compiler from a script to build
  something for the device: a device binary is a target with a Charon rule (skill `build`,
  `Bad system call: 12`).
- Paths: `os.projectdir()`, `os.scriptdir()`, `target:targetdir()`, `target:autogendir()`,
  `path.join(...)`. Write under the project only.
- Files: `io.readfile`, `io.writefile`, `io.gsub`. Copy with `os.cp`/`os.vcp`. Remove only what
  your own script wrote (`os.tryrm` on a path under `build/`).
- Environment: `os.setenv` changes the xmake process and every command it starts. Never set
  `XMAKE_GLOBALDIR`, `XMAKE_PKG_INSTALLDIR`, `XMAKE_PKG_CACHEDIR` or `CHARON_HOME` there: they move
  the shared store or Charon's firmware and emulator data (skill `xmake-basics`). `CHARON_RELEASE`
  is set by `xmake deb` itself (`v0.8.10:modules/packaging.lua:94`).

## 5. A script that runs xmake

- **Inside a build, configure or test of the same project: never start another `xmake`.**
  `xmake build` holds the project lock from before it configures until every target is built
  (xmake 3.1.1 `actions/build/main.lua:196-222`). `config`, `test` and `clean` take the same lock.
  A child `xmake` of those tasks waits for the lock its own parent holds, while the parent waits
  for the child, and the "please wait" line is printed only when the child has `-D`
  (`core/sandbox/modules/import/core/project/project.lua:224-227`). Measured: an `after_build`
  running `xmake f -y -D` hung after the parent's `imports:` line until it was killed, and the
  child's only output was `the current project is being accessed by other processes, please wait!`. In a task of your own, run
  another task in the same process with `task.run("build", {target = "<Name>"})`
  (`core/sandbox/modules/import/core/base/task.lua:35`), as Charon's `xmake deb` does
  (`v0.8.10:modules/packaging.lua:79,100,117`).
- **Pass the task first.** xmake takes the task only from the first argument, and only if it
  does not start with `-` (`core/main.lua:119-125`). `xmake -P <dir> where <pkg>` reads `where` as
  a target name and stops with `error: 'where' is not a valid target name for this project.`; write `xmake where -P <dir> <pkg>` (`v0.8.10:README.md:152-154`).
  Every option of `xmake device` and `xmake emulate` stands before the action as well.
- Pass `-y` to anything that may prompt. Never `--force`, never `xmake require --force`.
- **Never nest an emulator run inside `xmake test`.** An `on_test` calling `xmake emulate run`
  starts a second `xmake` in the project whose lock `xmake test` holds (xmake 3.1.1
  `actions/test/main.lua:581-631`): the case measured above with `xmake f` in `after_build`.
  `xmake emulate` inside `on_test` was not run (skill `xmake-tests`). Never `xmake emulate` or `xmake device` from any hook: run them yourself, one
  command at a time (skills `emulate`, `device`).
- A check script (Charon's `check` rule) runs outside any build and may call xmake, task first.

## 6. A task of your own

Only for a host-side job the user runs by name. `task("<name>")` with `set_menu { usage = "xmake
<name> [options] [arguments]", description = …, options = {…} }` and `on_run("main")` or an
inline function, reading options with `import("core.base.option")` and `option.get("<name>")`.
Option kinds are `k` (flag), `kv` (a value), `v` and `vs` (positional ones). Charon's own plugins
are the model (`v0.8.10:plugins/check/xmake.lua:1-14`). A `vs` argument takes everything after
it, so options go before it. Call `task.run("config")` first if the task needs the project's targets.

## Traps

- `os.exec("xmake …")` or `os.execv("xmake", …)` in `on_load`, `after_build` or `on_test` → never
  in the same project. Reason: the child waits forever for the lock its parent holds, silently
  unless the child has `-D`.
- `xmake -P <dir> where <pkg>` from a script → `xmake where -P <dir> <pkg>`. Reason: the task is
  only ever the first argument; otherwise it is a build of a target named `where`.
- `os.rm`/`os.tryrm` under `~/.xmake/packages` or `~/.xmake/cache`, or `xmake require --force`
  from a script, to "rebuild clean" → never. Reason: the store is shared by every project on the
  machine, and a changed package is already a new install path.
- `os.setenv("XMAKE_GLOBALDIR", …)` in a hook → never. Reason: a private store starts empty and
  rebuilds the compiler from source.
- `xmake emulate clean` in a script → never. Reason: it removes the shared caches of every project
  emulating on the machine.
- `on_install` or `on_link` on an app, daemon or tweak target "to add a step" → `after_*`.
  Reason: the target's own script replaces Charon's.
- Reading or editing `<Name>.app` in a target `after_build` → after `xmake` returns. Reason: the
  rule rewrites the bundle in the same stage, in no fixed order with yours.
- `os.iorun`, a download or `print` at the top level of `xmake.lua` → a hook. Reason: the top
  level runs on every command.
- A script that compiles with the Mac's `clang` for the device → a target with a Charon rule.
  Reason: the result is not built for the release and is never checked.
