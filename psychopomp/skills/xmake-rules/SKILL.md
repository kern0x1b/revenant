---
name: xmake-rules
description: Reference for Charon's xmake rules at the 0.8.10 pin — app, daemon, tweak, library, swift, check and the apple-ios rule under them — which kind each gives a target, where it installs, what it checks at the link, and every set_values/add_values name each rule and the modules it imports read (app.plist-file, app.plist, app.resources, app.url-scheme, app.frameworks, charon.install, charon.libraries, charon.control, charon.version, charon.entitlements, charon.strip, charon.waive.*, tweak.filter, swift.flags, swift.module, check.*, apple.compat, apple.architectures, emulate.*); how the rules' scripts combine with a target's own on_load/on_build/on_install; and when and how a project writes a rule of its own without bypassing Charon's checks. Use when choosing the rule for a target, when a value seems to have no effect, when a target should be a tweak, daemon or bundled library, or before writing rule(...) or a target script in an old-iOS project.
---

Derived from the `xmake-rules` skill of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# Charon's rules, and rules of your own

Every target that runs on the device gets its kind, toolchain, checks, placement, stripping and
signing from one of Charon's rules. This skill says what each rule at the pin (`v0.8.10`) does and
reads, and what a rule of your own may add. The app target's lines are the skill `project`; targets,
modes and configuration are the skill `xmake-basics`; flags are the skill `xmake-objc`; Swift is
the skill `xmake-swift`; packaging is the skill `package`. Read `PROJECT.md` first: it says whether
the product is an app, a tweak or a daemon.

## 1. The rules

Name each rule as `add_rules("@addon/charon/<rule>")` (`v0.8.10:rules/<rule>/xmake.lua`):

| Rule | Kind it sets | Installs to | At the link |
| --- | --- | --- | --- |
| `app` | `binary` | `<Name>.app` in `charon.install`, default `/Applications` | inputs' minimum, the binary's own checks. After the build it makes the bundle, strips and signs it, and checks every import against the release's shared cache |
| `daemon` | `binary` | `/usr/libexec/<name>`, or `charon.install` | inputs' minimum, the binary, and the import check against the release |
| `tweak` | `shared`, `<name>.dylib`, no `lib` prefix | `/Library/MobileSubstrate/DynamicLibraries/`, or `charon.install`; the install name is set to it | as `daemon` |
| `library` | `shared` | nothing by itself: an app bundles it (`app.frameworks`) | inputs' minimum, the binary. Its imports are checked with the bundle |
| `swift` | none; added next to one of the above | — | compiles the `.swift` files (skill `xmake-swift`) |
| `check` | `phony`, not built by default | — | nothing. `xmake check` runs it on the Mac |

- Every rule except `check` depends on the `apple-ios` rule (`rules/apple-ios/xmake.lua`). That
  rule sets the `apple-ios` toolchain, refuses a target whose project has no `apple_minimum` or no
  `includes("@addon/charon/apple-ios")`, and refuses a checkout nested in another project unless
  run with `xmake -P .`. You never add it yourself.
- `app`, `daemon` and `tweak` add the `ldid` and `firmware-tools` packages to the target.
- The rule sets the kind when the target loads, so a `set_kind` on such a target has no effect. Do
  not write one.
- `includes("@addon/charon/apple-ios")` and `includes("@addon/charon/emulate")` are includes, not
  rules (skills `install`, `emulate`).

## 2. The values, and who reads them

Only these names are read at the pin: a `git grep` of `values("` over `rules/`, `modules/` and
`plugins/` at `v0.8.10` finds nothing else. Any other name is silently ignored. Paths are relative
to the `xmake.lua` that declares the target.

| Value | Read for | What it does | Where |
| --- | --- | --- | --- |
| `app.plist-file` | `app` | the `Info.plist` to start from | `modules/apple/bundle.lua:29` |
| `app.plist` | `app` | `KEY=VALUE`, repeatable with `add_values`, over the file | `bundle.lua:18` |
| `app.resources` | `app` | folders copied flat into the bundle; files copied as they are | `bundle.lua:168` |
| `app.url-scheme` | `app` | one URL scheme; replaces `CFBundleURLTypes` | `bundle.lua:59` |
| `app.frameworks` | `app` | shared-library targets it `add_deps`, or packages by alias, copied to `Frameworks/` | `bundle.lua:88-107` |
| `charon.install` | `app`, `daemon`, `tweak` | the install folder on the device | `rules/*/xmake.lua` |
| `charon.libraries` | `daemon`, `tweak` | packages whose shared libraries it loads, placed in `/usr/lib/charon/<Package>/` | `modules/apple/platform.lua:330-398` |
| `tweak.filter` | `tweak` | the MobileSubstrate filter plist, installed as `<name>.plist` beside the dylib | `rules/tweak/xmake.lua:25-28` |
| `swift.module`, `swift.flags` | `swift` | module name; extra `swiftc` options | `rules/swift/xmake.lua` |
| `check.script`, `check.command` | `check` | a script run by the interpreter its extension names (`.py .sh .rb .pl .js`), or any program, with arguments | `modules/checks.lua:21-37` |
| `check.files`, `check.pass-files`, `check.needs-files` | `check` | globs of tracked files it concerns; pass the matching files as arguments; stay quiet when none match | `modules/checks.lua:57-85` |
| `charon.control` | any | the Debian control file: makes the target part of a package; required for `charon.libraries` | `modules/packaging.lua:53`, `platform.lua:331` |
| `charon.version` | any | the package's version instead of `set_version` | `packaging.lua:57` |
| `charon.licenses` | any | files copied to `/usr/share/doc/<Package>/` | `packaging.lua:65` |
| `charon.maintainer-scripts` | any | a folder: each file in it goes into the package as a maintainer script | `packaging.lua:68`, `modules/debian.lua:138-145` |
| `charon.entitlements` | any | a plist `ldid` signs into the binaries (in an app, into its executable only) | `platform.lua:417-427,463` |
| `charon.strip` | any | the strip options, default `-x` | `platform.lua:412-415` |
| `charon.waive.<check>` | any | a reason; `<check>` is `thumb-interworking`, `pagezero`, `entitlements` or `weak-imports` | `platform.lua:12-17`, `modules/apple/macho.lua:46-48` |
| `charon.waive.input-minimum.<package>` | any | a reason; skips the minimum check of that package's archives | `platform.lua:80-82` |
| `apple.compat` | any | calls renamed to `charon@apple-compat`'s shims | `rules/apple-ios/xmake.lua:29-38` |
| `apple.architectures` | `app` | more than one architecture: `xmake deb` builds and merges the slices | `packaging.lua:118` |
| `emulate.network`, `emulate.timing` | any | the emulator's network (`isolated`, `loopback`, `host`) and `strict` timing | `plugins/emulate/main.lua:19-40` |

Also read: xmake's own `add_installfiles` on `app`, `daemon` and `tweak` targets. The files go into
the package at their install paths, e.g. a daemon's LaunchDaemons plist (`platform.lua:429-435`).

A waiver is a statement that a check does not apply, with the reason. It is never a way to a green
build. Write one only as the skills `build` and `self-review` allow, with the user's agreement,
under `## Limits`.

## 3. How the rules' scripts and yours combine

xmake 3.1.1 runs the scripts of a target and of its rules in a fixed order:

- `on_load`: the rules first, then the target's (`core/project/target.lua:124-136`). A target
  `on_load` that sets the kind, the toolchain or the packages undoes what Charon set.
- `on_config`: the rules first, the target's last (`modules/private/action/build/target.lua:252-256`).
- `on_build`, `on_link`, `on_prepare`: a target's own script **replaces** every rule's script of
  that stage (`…/build/target.lua:275-278`). `on_install`: a target's own replaces the rules'
  (`actions/install/install.lua:30-44,80`). Charon's `on_install` copies the app into its folder,
  and places, strips and signs a daemon's or tweak's binaries (`platform.lua:398-427`). A target
  `on_install` of your own leaves them out of the package, or unsigned.
- `before_*` and `after_*`: both the target's and every rule's run. Charon's checks are in
  `after_link`, and the `app` rule makes the bundle in `after_build`. That step deletes
  `<Name>.app` and writes it again (`platform.lua:437-440`), so a file a script put there earlier
  is gone.

## 4. A rule of your own

Write one only for a step that no Charon value covers: a data file turned into source (a table, a
generated header), or a host tool the build must run. Resources go through `app.resources`, plist
keys through `app.plist`, libraries through `app.frameworks`/`charon.libraries`, and package
contents through `charon.*` and `add_installfiles`.

The shape in xmake 3.1.1, as its own `protobuf` rule does it (`rules/protobuf/xmake.lua:25-34`,
`rules/protobuf/proto.lua:85-92,215`):

- `rule("<name>")` with `set_extensions(".<ext>")`, applied as `add_rules("<name>")` next to the
  Charon rule, with `add_files("<dir>/*.<ext>")`.
- In `after_load`, register the object the generated file will become:
  `table.insert(target:objectfiles(), target:objectfile(<generated>))`, with the generated file
  under `target:autogendir()`.
- In `on_buildcmd_file(function (target, batchcmds, sourcefile, opt) … end)`: run the host tool
  with `batchcmds:vrunv(...)`, then `batchcmds:compile(<generated>, <object>)`. It loads the
  **target's** compiler (`modules/private/utils/batchcmds.lua:347-376`), so the object gets
  Charon's toolchain and records the minimum. Declare the inputs with
  `batchcmds:add_depfiles(sourcefile)` and `batchcmds:set_depmtime(...)`.

How to know it worked: `xmake -r -y -v > .logs/build.log 2>&1` shows the generated file compiled
with `-target … -miphoneos-version-min=<apple_minimum>` like the others, then `build ok` and the
`imports:` line.

What a rule or target script of yours must not do. Each of these bypasses a check that stands for
the device:

- set `kind`, `toolchains`, `-target`, `-miphoneos-version-min` or `-isysroot`, or clear the packages
  of a target that has a Charon rule;
- define `on_link`, `on_build` or `on_install` on such a target;
- compile or link anything for the device with the Mac's `clang` (`os.vrunv("clang", …)`, `xcrun clang`, `cc`). The
  binary is a Mac's, not the release's (skill `build`, `Bad system call: 12`);
- strip, re-sign or edit a binary after Charon did (`xcrun strip`, `ldid`, `codesign`);
- add `-w`, `-Wno-…`, `-disable-availability-checking` or a `charon.waive.*` value;
- call `xmake` again, or delete anything in the shared store (skill `xmake-scripting`).

## Traps

- `charon.libraries` on an app → `app.frameworks`. Reason: the app's bundle reads only
  `app.frameworks`; `charon.libraries` is the daemon's and tweak's.
- A `library` target expected on the device by itself → `add_deps` it from the app and name it in
  `app.frameworks`. Reason: the rule installs nothing; `app.frameworks` refuses a target that is
  not shared.
- `add_rules("xcode.application")`, `xcode.framework` or `xcode.bundle` beside a Charon rule →
  never. Reason: xmake's Xcode rules need Xcode and replace the bundle Charon checks and signs.
- `set_values("app.infoplist", …)`, `swift.modulename`, `tweak.plist` or another guessed name →
  the names in §2. Reason: an unknown value is ignored without a word.
- A check target that builds or tests the app → a check is host-side (lint, pre-commit). Probes on
  the device are the skill `checks`, host tests are the skill `xmake-tests`.
- A check script that runs `xmake -P <dir> where <pkg>` → `xmake where -P <dir> <pkg>`. Reason:
  xmake takes the task only from the first argument (skill `xmake-scripting`).
- Copying files into `<Name>.app` from `after_build` → `app.resources`. Reason: the rule rebuilds
  the bundle and your file disappears.
