---
name: install
description: Prepare the user's Mac to build apps for old iOS with Charon and xmake — Command Line Tools, Homebrew's xmake, llvm and dpkg, the Charon addon and package repository pinned to a release tag in the project's xmake.lua — then find out what is already built in the shared package store and pay the real first-build cost (the toolchain's compiler, and for Swift the Swift compiler, built from source, an hour or more). Use right after the interview (init), when PROJECT.md has no install evidence, when xmake or the addon is missing, or when someone asks how long the first build takes or whether the toolchain is already built.
---

# Install the host and pin Charon

The user's Mac gets the tools, and the project directory gets the few lines of `xmake.lua` that
pin Charon: the addon (rules, checks, `xmake firmware`, `xmake deb`) and the package repository
(the SDK, linker, compiler) at one release. The step ends when the pinned addon answers in the
project and the toolchain packages are installed in the shared store.

Read `PROJECT.md` first. If it is missing or its decisions are not confirmed, follow the skill
`init` and come back. Create `.logs/` in the project; every long command below writes there.

## 1. Check the host

Look, do not ask:

```
uname -sm                 # Darwin arm64
sw_vers -productVersion
xcode-select -p           # /Library/Developer/CommandLineTools (or an Xcode)
brew --version
df -h ~
```

- `uname -sm` must say `Darwin arm64` if the plan includes the emulator: it runs on macOS arm64
  hosts only. Building works on macOS; nothing here runs on Linux or Windows.
- No `xcode-select -p` path: run `xcode-select --install` and let the user finish the dialog.
  Xcode itself is not needed; the build calls `xcrun swiftc` (every project's first configure
  compiles Charon's firmware tool with it, even for an Objective-C app), `xcrun strip`, `git` and
  `plutil` from these tools. Check: `xcrun --find swiftc` prints a path.
- No `brew`: the user installs Homebrew from https://brew.sh first. Say so and wait.

## 2. Install the tools

```
brew install xmake llvm dpkg
```

- `xmake` is the build system (3.1.1 or later: it has `xmake addon`, which the pin needs).
- `llvm` is Homebrew's LLVM: Charon's linker package (ld64) finds `llvm-config` through it while
  it builds. It is not the compiler your app is built with; that one Charon builds itself.
- `dpkg` gives `dpkg-deb` and `dpkg-scanpackages` for the skills `package` and `cydia-repo`.

How to know it worked:

```
xmake --version | head -1             # xmake v3.1.1+… or later
xmake addon --help | grep -- --install
brew --prefix llvm                     # a path such as /opt/homebrew/opt/llvm
dpkg-deb --version | head -1
```

## 3. Find the release to pin

Charon is pinned by a pair of tags: `charon-repo-<X>` for the package repository and `v<X>` for
the addon, the same `<X>`.

```
git ls-remote --tags https://github.com/kern0x1b/charon.git 'charon-repo-*' 'v*'
```

Pin **0.8.10**: these skills were checked against that pair, and every fact they state holds at
it. Confirm both `refs/tags/charon-repo-0.8.10` and `refs/tags/v0.8.10` are listed. A higher pair
may exist; moving to it is the user's decision, and then every command of these skills is to be
checked again on the first build. The `charon-repo-<X>` tag is the commit that lists `v<X>` among
the addon's versions, so a `v<X>` without its `charon-repo-<X>` is not installable yet. Never pin
`main` or a range: xmake resolves those against its own clone and does not pull it again.

A feature a later skill needs may exist only on Charon's `main`, after the tag. Those skills say
so where it matters ("needs Charon after 0.8.10"); do not switch the pin to `main` to get it.

## 4. Write the pin into xmake.lua

Create `xmake.lua` at the project root with the project-wide lines only; the skill `project` adds
the target. Write them yourself, in this order, one decision each:

- the project's name and version (`set_project`, `set_version`; the version becomes the app's
  `CFBundleVersion` and the package version);
- `set_policy("package.requires_lock", true)`, so the resolved packages are written to
  `xmake-requires.lock`;
- the pin, exactly these two lines with your `<X>`:
  ```lua
  add_repositories("charon https://github.com/kern0x1b/charon.git charon-repo-0.8.10")
  add_addons("charon v0.8.10")
  ```
- `set_config("apple_minimum", "<the lowest release from PROJECT.md>")`, before the include;
- `includes("@addon/charon/apple-ios")`, which requires the SDK, ld64, ldid, the compiler and
  the firmware tools at the versions the addon pins;
- `set_defaultplat("iphoneos")` and `set_defaultarchs("iphoneos|<arch>")` with the architecture
  from `PROJECT.md` (e.g. `armv7`), so a plain `xmake` builds for it.

## 5. See what is already built

The package store `~/.xmake/packages` is shared by every project on the machine. Another project
on the same Charon tag may already have built the compiler; then the first build takes seconds.
Check before starting it (this also installs the addon, which is quick):

```
xmake require -y --info 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > .logs/require-info.log
grep -A20 'require(charon@llvm 23.1.1)' .logs/require-info.log | grep -m1 'installdir:'
```

With no package named, `--info` describes the project's own requires, as the pinned addon states
them (`charon@llvm 23.1.1` at Charon 0.8.10); a package named on the command line is resolved
alone and may differ from the one the project uses, and the store holds several llvm installs.
It prints `-> installdir: <home>/.xmake/packages/l/llvm/23.1.1/<hash>`, the exact install this pin
would use. Test that path:

```
test -f <installdir>/manifest.txt && echo built || echo not-built
```

- `built`: the compiler is there; the first configure finishes in seconds.
- `not-built`: the first configure compiles it from source (step 6). `--info` may leave an empty
  folder at that path; an install counts only with its `manifest.txt`.
- The same log shows `require(charon@iphoneos-sdk 16.4):` and `require(charon@ld64):` with their
  own `installdir:` lines; test them the same way for the whole picture. ld64 is printed without
  its version because it arrives first as the SDK package's dependency, which names none. For a Swift app, check
  `/s/swift-runtime/` and `/s/swift/` the same way once the project requires them, and `/s/styx/`
  when it requires Combine (skills `swift`, `combine`).

## 6. Configure once, and pay the first-build cost

```
xmake f -y > .logs/configure.log 2>&1
```

Run it with the longest timeout your shell tool allows, and if it is backgrounded, wait for it;
never start a second `xmake` in the same project meanwhile (the two lock each other). What it
does on a machine with nothing built:

- downloads the iPhoneOS SDK from theos/sdks (about 230 MB installed) and builds ld64 (with
  Apple's libtapi), ldid, libplist and OpenSSL for the host, and cmake and ninja if needed;
- **builds Charon's LLVM/clang from source: about an hour**, the longest single step. There is
  no binary cache; `xmake borrow llvm` only copies from another store already on this machine;
- for a Swift app, later: the Swift compiler from source, which builds its own copy of LLVM as
  well and so takes longer than the step above, plus a swift.org toolchain download for its
  bootstrap (about 1.1 GB installed).

The installed results are small (the compiler about 120 MB), but a compiler's sources and build
tree take several gigabytes while it builds; check `df -h ~` first.

How to know it worked:

```
tail -5 .logs/configure.log                       # no "error:" line; exit status 0
xmake addon --list | sed -n 2p                    # -> charon v0.8.10: …
grep -n 'version = "v' xmake-addons.lock          # version = "v0.8.10"
git -C .xmake/macosx/arm64/repositories/charon log --oneline -1
                                                  # 8201449 Advertise charon v0.8.10
```

`xmake addon --list` run inside the project shows the addon version this project uses; outside
the project it shows whichever version was installed last. The first configure may print
`checking for Xcode SDK ... no`: expected, no Xcode is used.

## 7. Record it

In `PROJECT.md` under `## Progress`, the install line: the pin (`charon-repo-<X>` / `v<X>`), the
`xmake addon --list` line, `.logs/configure.log`, and whether the compiler was built or found.
Commit `xmake.lua`, `xmake-requires.lock` and `xmake-addons.lock` if the project is a git
repository; keep `build/` and `.xmake/` out of it.

Then follow the skill `firmware`.

## Traps

- **`xmake-addons.lock` names another version** (e.g. `v0.0.0-…` or an older tag), and
  `xmake addon --list` in the project agrees → stop and tell the user; do not edit the lock or
  reinstall the addon to force it. Reason: xmake (3.1.1) keeps one "active" version of an addon
  per machine and writes the lock from it; when `v<X>` was already installed and another project
  installed a different Charon later, the lock records that other one and the build uses it.
  xmake has no command today that makes the pinned version active again, so this is a limit of
  the build system, not something to patch around. On a machine where only this project's Charon
  was ever installed, it does not happen.
- `xmake require --force`, `rm -rf ~/.xmake/packages/…`, or a private `XMAKE_GLOBALDIR` to "start
  clean" → never. Build against the shared store. Reason: the recipes digest their sources and
  patches, so a changed package is already a new install path; a private store rebuilds LLVM
  from source.
- Running `xmake` without `-y` from a script or an agent → always `-y`. Reason: xmake asks before
  it installs a package or an addon, and a command with no one to answer waits forever.
- Stopping the first configure because it "hangs" → look at the process, not the log:
  `pgrep -fl 'cmake|ninja|clang'` shows the compiler building. Killing it mid-way can leave
  `.git/index.lock` in the package's source cache under `~/.xmake/cache/packages/`; remove that
  one file before building again.
- Pinning `main`, or `add_addons("charon latest")` → the tag pair. Reason: a branch is resolved
  once against xmake's own clone and never pulled again; the tag is reproducible.
- Homebrew's `clang` or `cc` used to compile anything for the device → never; only targets built
  through Charon's rules. Reason: a binary for the wrong target dies with `Bad system call: 12`
  on the device before its own code runs.
