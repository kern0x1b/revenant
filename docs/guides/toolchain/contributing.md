# Working on the toolchain

Read this before changing `toolchain/`. The workspace contract and the repository's `AGENTS.md` apply first.
What the toolchain is, and why it is built this way, is in [design](../../explanation/toolchain/design.md).

## Where to look

- The tasks: [write a port](../../tutorials/toolchain/port.md), [write a package](packages.md), [run on the emulator](emulate.md),
  [run the tests](../../reference/toolchain/tests.md).
- The facts: [rules and values](../../reference/toolchain/rules.md), [commands](../../reference/toolchain/commands.md),
  [packages](../../reference/toolchain/packages.md), [tools](../../reference/toolchain/tools.md).
- Skills in the top `.agents/skills/`: `emulator` drives `xmake emulate`, `device` reaches a phone. The xmake reference skills come from the `xmake-skills` plugin pinned in
  `.claude/settings.json`, never from a copy in this repository.

## Layout

| Path | Holds |
| --- | --- |
| `addon.lua`, `addons/r/revenant/xmake.lua` | the addon `revenant`, and the package that installs it for `add_addons` |
| `toolchains/apple-ios/` | the `apple-ios` toolchain: the compilers, SDK and flags every target gets |
| `rules/` | the target rules: `app`, `apple-ios`, `check`, `daemon`, `library`, `macro`, `swift`, `tweak` |
| `includes/apple-ios/`, `includes/emulate/` | what a port includes: `@addon/revenant/apple-ios` and `@addon/revenant/emulate` |
| `plugins/` | the verbs: `check`, `compile-commands`, `deb`, `device`, `emulate`, `firmware`, `where` |
| `modules/apple/` | the Lua the rules and verbs run; `modules/gyb/` expands Swift's `.gyb` templates in Lua |
| `packages/<letter>/<name>/` | package definitions, grouped as `build-tools`, `runtimes`, `frameworks`, `libraries`, `emulator`, `tweaks` |
| `tools/` | developer tools, see [tools](../../reference/toolchain/tools.md) |
| `tests/` | `light.lua`, which runs the addon's tests; `addon/`, `common/`, `corpus/`, `emulate/`, `gen/`, `swiftui/` |

`./xmakew l tools/check.lua layout` from the repository root reports what is not yet in the repository's layout.

## Before handing a change over

- `./xmakew l tools/check.lua toolchain` runs `tests/light.lua`, which runs the addon's tests.
- `./xmakew l tools/check.lua layout` from the repository root.
- The skill `emulator-session` for a run on the emulator.
- A change that spans components is one series in the repository, one commit per component it touches.

## Conventions

- Tracked files hold no personal data: no device address, hostname, credential or absolute `/Users/<name>/` path.
  Use `$HOME`, placeholders and the gitignored `device.env`, which names the phone in `DEVICE_HOST`, `DEVICE_PORT`,
  `DEVICE_UDID` and `DEVICE_PASSWORD`.
- Build output (`build/`, `.xmake/`) is gitignored, and comes back from the package definitions.
- A package takes a dependency by its own name, `package:dep("name")`. A host tool brings its own dependencies,
  and they meet a target's dependencies under the same key, where the later one wins: tdlib once linked a macOS
  libcrypto that way. Keep a host tool, or anything with library dependencies, out of a package other packages
  depend on. Where a dependency's folder goes to CMake or a linker, use `target_dependency(package, name)` from
  `modules/apple/dependency.lua`.

## Traps

Each entry: the wrong pattern, the right one, and the mechanical reason.

- **The shared package store.** Wrong: `xmake require --force`, `xrepo install --force`, deleting anything under the
  store, or a private `XMAKE_GLOBALDIR` to pick up a changed recipe or patch. Right: build normally.
  `./xmakew` points `XMAKE_GLOBALDIR` at `$HOME/.revenant/cache/xmake-global`. Reason: the packages that matter
  (`llvm`, `swift-runtime`, `libcxx`, `swift`) hash their sources, patches and definition into a
  digest (`the deleted registry package xmake.lua`, `packages/s/swift-runtime/digest.lua`), so a changed
  backport or patch is already a different package with its own install path. A private store re-resolves the whole
  chain from the network, up to building LLVM. A build's own output that must survive (a crash log) goes to a file
  of its own: `./xmakew build ... > "$HOME/.revenant/cache/<task>/build.log" 2>&1`.

- **Device-side binaries.** Wrong: building a device binary, even a throwaway probe, with the host's `cc` or `clang`.
  Right: a `target()` using `@addon/revenant/daemon` (or `app`, `tweak`), built by the `apple-ios` toolchain like any
  port. Reason: a Mach-O built for the wrong target dies with `Bad system call: 12` (SIGSYS) before its own code runs
  on the device's old kernel, which looks like a codesigning or sandbox rejection.

- **`NSMapTable` with non-object keys or values.** Wrong: default options when a key or value is an opaque C pointer
  bridged with `(__bridge id)`. Right: `+mapTableWithKeyOptions:valueOptions:` with `NSPointerFunctionsOpaqueMemory |
  NSPointerFunctionsOpaquePersonality` on the non-object side. Reason: default options send retain and release to the
  pointer, and `objc_retain` on a non-object crashes inside `NSConcreteMapTable` with no hint of the cause.

- **Calling a block by its own pointer.** Wrong: casting a block's pointer to a C function type and calling it. Right:
  read `invoke` from the block layout `{isa, flags, reserved, invoke, ...captures}` and call that, bridging through
  `void *` first, since ARC forbids calling an Objective-C pointer as a function. Reason: the block's first word is
  `isa`, not code.

- **`NSInvocation` argument lifetime.** Wrong: `-setArgument:atIndex:` without `-retainArguments` when the argument's
  source can leave scope before `-invoke`. Right: call `-retainArguments` straight after creating the invocation.
  Reason: `-setArgument:atIndex:` copies bytes, so an object pointer dangles, and the crash lands in the callee's
  ARC prologue (`objc_storeStrong`), not at the cause.

- **`NSInteger` and `NSUInteger` together.** Wrong: subtracting an `NSUInteger` (`calendar.firstWeekday`) from an
  `NSInteger` without a cast. Right: cast the unsigned side to `NSInteger` first. Reason: the signed side is converted
  to unsigned, so the result wraps to a huge positive number. Wrong answer, no crash, no warning.

- **`revenant.libraries` and `verify_placed`.** Wrong: a target `add_requires`s and `add_packages` a backport package,
  and linking still fails with "these imports are not exported by the device's iOS". Right:
  `set_values("revenant.libraries", "<the alias add_requires gave the package>")`. Reason: `verify_placed` in
  `modules/apple/platform.lua` takes the plain, weak-linked path while `revenant.libraries` is empty, and that path
  does not recognise the backport dylib as build-provided. Related: `@addon/revenant/*` resolves to a version-pinned
  copy under `~/.xmake/addons/revenant/<version>/`, not to the working tree, so an uncommitted edit under `modules/`
  reaches a build only once it is committed.

- **`+load` in a backport.** Wrong: expecting `+load` to see a method that the library's categories add, or replacing
  a release method with no same-selector category beside the replacement. Right: decide on the release alone, and
  keep a same-selector category beside the replacement, as `Foundation/NSBundle+ReceiptURL.m` does. Reason: `+load`
  runs before the constructor attaches `__DATA,__port_catlist`, and the selector check counts only what categories add.

- **`git format-patch --no-walk` takes SHAs, not a range.** Wrong: `git format-patch --no-walk A..B`, which git reads as
  one literal revision and writes a 0-byte file. Right: pass the SHAs as separate arguments, or let the range walk:
  `git format-patch A..B -o <dir>`. Check the byte size of every patch: a headerless or 0-byte file is this mistake.

- **A seam the port owns.** Wrong: a `revenant_` C function that a library exports for another library of the package,
  declared like an API. Right: declare it with `REVENANT_SEAM` before its return type, on a line of its own, in a
  header and in its definition. `seam_symbols()` in `modules/apple/backports.lua` reads that declaration, and `link()`
  keeps the symbol exported. Reason: a `revenant_` name is not Apple API, and the backports checks count it as
  internal.

- **A C function shared between backport files.** Wrong: calling from one file a C function defined in a file that
  implements a class or exports an API symbol. Right: define it in a file that exports no API symbol of its own, as
  `UIKit/UIViewController+DocumentMenu.m` does, or link the files through Objective-C methods. Reason: a file whose
  exports a band's release already has is left out of that band, so the call is an undefined symbol in later bands
  only. A one-band build links and passes; only the all-band build shows it.

- **The compiler cache.** Wrong: reading a hit rate as proof that the output is the same. Right: `./xmakew` exports
  `CCACHE_DIR`, `CCACHE_NOHASHDIR` (1 by default) and `CCACHE_MAXSIZE`, and the proof is that the cached objects match
  a `CCACHE_DISABLE=1` build. Reason: with `CCACHE_NOHASHDIR`, a source is named the same way from every worktree, so
  they share one cache; with `hash_dir = true` each worktree's directory enters the key, every band builds alone with a
  cache that only misses, and nothing fails. `CCACHE_DISABLE`, set to anything including empty, turns the cache off.
  `CCACHE` names a program, checked before it is used, so a stale one costs the cache and not the build. The key ignores
  the spelling of a path and the object does not, so a relative and an absolute spelling of one file can store two
  objects under one key.

- **A job runner started inside a job.** Wrong: `async.runjobs`, or anything else on xmake's scheduler, called from a
  `package:on_install` or from a function that one calls. Right: let `width()` in `modules/apple/backports.lua` see
  it, which compiles one unit at a time when `scheduler.co_count() > 1`. Reason: a runner started inside a runner never
  returns. Every object is written, nothing is printed, and the process stays alive, whatever `isolate` says.

- **A working copy installed as the addon.** Wrong: a scratch project with `add_addons("revenant")` whose
  `add_repositories` points at a worktree or clone, run against the shared `~/.xmake`. Right: test a package or a module
  with a `XMAKE_GLOBALDIR` of its own, as `tests/addon/store_test.lua` does. Reason: on xmake 3.1.1 every addon install
  becomes the machine's active version, and every new project then locks that copy instead of the version it declares.

- **Package source caches are patched.** Wrong: quoting what an upstream project does from the tree a package build
  extracted into xmake's package cache. Right: read the pinned commit from a fresh download or the upstream git object,
  and say which one was read. Reason: the extracted tree already has the recipe's patches and in-place edits applied.
