# Rules, values and checks

The target rules and the values each one reads, the settings a port sets for the toolchain, the checks every binary is held to where it is linked, and where the installed files go. How to use them is in [write a port](../../tutorials/toolchain/port.md).

## Target rules

| Rule | Target | Reads |
| --- | --- | --- |
| `@addon/revenant/tweak` | a MobileSubstrate dylib | `tweak.filter`, `revenant.install`, `revenant.libraries` |
| `@addon/revenant/daemon` | an executable in `/usr/libexec` | `revenant.install`, `revenant.libraries`; its LaunchDaemons plist through `add_installfiles` |
| `@addon/revenant/app` | `Name.app` | `app.plist-file`, `app.plist`, `app.resources`, `app.frameworks`, `app.url-scheme` |
| `@addon/revenant/library` | a shared library an application bundles | the values on any target below; checked, stripped, signed and import-checked with the bundle |
| `@addon/revenant/swift` | added beside one of the rules above | `swift.module` (default the target's name), `swift.flags`, `swift.application_floor` (a version such as `15`: a reference to a declaration outside the system modules is checked as if the deployment target were at least that version; system declarations are still checked against the deployment target) |
| `@addon/revenant/rust` | a Rust staticlib for armv7 on iOS 6.0, built by cargo | `rust.crate` (the folder with its `Cargo.toml` and `Cargo.lock`, relative to the project), `rust.library` (the crate's `[lib]` name; default the target's name, with `-` as `_`), `rust.package` (the `-p` package of a workspace), `rust.features` (the exact feature set; the default features are off), `rust.rustflags` (rustc flags, added to `RUSTFLAGS`) |
| `@addon/revenant/check` | a project check | `check.*`, see below |

`rust` needs `revenant@rust` (see [packages](packages.md)) and an armv7 target with `apple_minimum` 6.0. It builds the crate with the pinned nightly's cargo for [the armv7 iOS 6 spec](../../../toolchain/src/rust/armv7-apple-ios6.json), `-Zbuild-std` over core, alloc, std and panic_abort, and the apple-ios toolchain's clang for the crate's C code. Its archive is a static library, so a target that `add_deps()` it links it, and the public `links` and `linkdirs` it sets reach that target. The how-to is in [build a Rust crate](../../guides/toolchain/rust.md).

`revenant.libraries` names the packages whose shared libraries the target loads. A tweak or daemon finds them in `/usr/lib/revenant/<Package>/`; an application carries them in its bundle with `app.frameworks`.

`app.plist` takes `KEY=VALUE` lines over `app.plist-file`. `app.resources` copies folders flat into the bundle. `app.frameworks` puts the shared libraries of packages into `Frameworks` under their install names, and each shared-library target the application `add_deps()` is loaded through `@executable_path`. Info.plist keys that neither file gives are derived: the bundle and executable names, the project version, and `MinimumOSVersion`.

`swift` compiles the target's `.swift` files as one module. It compiles the whole language when the project requires `revenant@swift-runtime` (with `revenant@libcxx`), and Embedded Swift when it requires `revenant@swift-embedded`. It refuses both, or neither.

Files a tweak, daemon or app names with `add_installfiles` go into its package at the path given, under the package root.

## Values on any target

| Value | Meaning |
| --- | --- |
| `revenant.entitlements` | entitlements file; signed with `ldid`, and the signature is read back |
| `revenant.strip` | strip arguments, default `-x`; applied after the checks |
| `revenant.control` | the Debian `control` file of the package |
| `revenant.maintainer-scripts` | the path of the package's maintainer scripts, copied into the package |
| `revenant.licenses` | files copied to `/usr/share/doc/<Package>/` |
| `revenant.version` | the package version, when it is versioned apart from the project |
| `revenant.waive.<check> "reason"` | waives one named check, with the reason it is safe |
| `revenant.waive.input-minimum.<package>` | waives the minimum-release test of one package's objects |
| `emulate.network` | `isolated` (default), `loopback` or `host` |
| `emulate.timing` | `strict`: the run refuses any time scale but 1 |
| `apple.architectures` | `add_values` the slices an application is packaged for |
| `apple.compat` | calls renamed to the `apple-compat` shims, for example `clock_gettime` |
| `apple.objc_bool` | `bool`: compile the target's Objective-C and Objective-C++ with `BOOL` as `bool`, as on arm64; see the apple-ios section |
| `package.librarydeps.strict_compatibility` | set in a port, so packages depending on a rebuilt package are rebuilt too |

A package's `add_configs("revision", {default = "2", readonly = true})` is raised by hand when its script changes in a way the hash cannot see.

## The apple-ios rule

`apple.objc_bool` set to `bool` adds `-U__OBJC_BOOL_IS_BOOL -D__OBJC_BOOL_IS_BOOL=1` to the target's Objective-C and Objective-C++ flags, so `BOOL` is `_Bool`. The undefine comes first because clang predefines the macro, and a bare define is a redefinition warning, which `-Werror` makes an error; the pair raises no warning and hides none. So `BOOL` is `_Bool` here, as on arm64, the architecture the source was written for. On armv7 `BOOL` is `signed char`, and the two differ in two places. A one-bit signed bitfield, `BOOL on : 1`, stores YES as -1 under `signed char`, which changes the value read back; the flag removes that difference. And `@encode(BOOL)` is `c` under `signed char` and `B` under `_Bool`. Calls in both directions pass one byte that holds 0 or 1, so the flag changes no call, only the type encodings. Methods of a class compiled this way carry `B` in their encodings, so the KVC and `NSInvocation` paths that read those encodings on a BOOL property must be checked on iOS 6 before a port relies on them. `toolchain/tests/objc_bool/runtime_check.m` is that check, to run in the emulator with the flag set; it is not verified yet. The compile-time half, the bitfield under `-Werror` and the encoding in the IR, is `objc_bool_test`.

The rule passes `-Wno-incompatible-sysroot` to armv6, armv7 and armv7s targets. Clang warns that the sysroot is for another target: measured against SDK 16.4 and SDK 26.2, every 32-bit target gets the warning and arm64 gets none. It is inherent to building armv7 against a current SDK, the design of this port, so it is silenced for those arches only.

## Settings of the project

| Setting | Meaning |
| --- | --- |
| `apple_minimum` | the oldest release the port runs on, for example `6.0`. A release the architecture cannot run is refused, naming the architectures that can. |
| `apple_sdk` | the SDK version. The default is 26.2, the one SDK every configure uses; `16.4` is also available. |

## Checks on every linked binary

The rules run these where a binary is linked, before anything strips or signs it. Each one has a name, which `revenant.waive.<check>` can waive with a reason.

- **Minimum release.** Every object a target links and every member of its packages' static archives records the port's minimum. An input from outside the graph that is newer is refused; one that is older, or none, is reported by name. A package that cannot record it is waived with `revenant.waive.input-minimum.<package>`.
- **Thumb interworking.** On armv7, bit 0 of every rebased code pointer is set exactly when the function it names is Thumb. A binary none of whose code pointers names a function it can check is refused as stripped.
- **`__PAGEZERO`.** At least 4 GB on arm64; ends where `__TEXT` starts on armv7. Waived with `revenant.waive.pagezero`.
- **`LC_ENCRYPTION_INFO`.** A 32-bit ARM library that carries this load command is refused. Only an executable carries it; iOS 6 does not start a MobileSubstrate tweak that has one.
- **System calls.** A call a minimum release lacks is refused.
- **Imports.** Every import is looked up where dyld looks for it: in the library its binding names and in what that library re-exports. A symbol the device exports only from another library is refused. The reference is the device's own dyld shared cache.
- **Weak imports.** A weak import of a symbol the checked release does not export is a warning naming the binary and the first twelve symbols (all of them under `xmake -v`). It is refused when the image is released, that is under `xmake deb`, in Revenant's guest programs, or with `REVENANT_RELEASE` set, unless the target waives `weak-imports` and says why every call is guarded. The symbols the compiler emits by itself (ARC entry points, the block runtime, emulated TLS, the wide atomics) are refused in every case; their list is `ARRIVED` in `modules/apple/compat.lua`.
- **Selectors.** Each selector the binaries reference (`__objc_selrefs`) that neither they nor any class or protocol of the release implements is a warning. Methods of the build's own classes and categories count as implemented, and so do methods a runtime component adds at run time, declared in a `__DATA,__port_addsel` section.

The import check reads the release's system libraries from `~/.revenant/dyld/<release>/`: `dyld_shared_cache_<arch>` and its subcaches, or `libraries_<arch>/` before iOS 3.1. It reads every cache format from iOS 3.1 to today. It uses the earliest release of the slice's architecture that is not older than `apple_minimum` (iOS 6.0 for an armv7 port at 6.0, iOS 7.0 for its arm64 slice). If those files are not held, the check offers to fetch them; see [commands](commands.md#firmware).

## Checks as targets

A check is a target with `add_rules("@addon/revenant/check")`:

| Value | Meaning |
| --- | --- |
| `check.script` | a script to run; the interpreter comes from its extension (`.sh`, `.rb`, `.pl`, `.js`) |
| `check.command` | any program, instead of a script |
| `check.files` | the files it covers, as patterns |
| `check.pass-files` | `true`: pass the files the check covers to it |
| `check.needs-files` | the check stays quiet while there are no such files |

A check runs when a file it names is staged or changed, and on every run that is given no `--staged` or `--changed` flag, when it is given every tracked file it names. A script that calls xmake passes the task first: `xmake where -P DIR tdlib`, not `xmake -P DIR where`, which xmake reads as a target name.

## Installed paths

| Path | What is there |
| --- | --- |
| `/usr/libexec/` | a `daemon` executable, through `revenant.install` |
| `/usr/lib/revenant/<Package>/` | the shared libraries a tweak or daemon loads, of the packages named by `revenant.libraries`; only the libraries it loads |
| `/usr/lib/revenant/org.revenant.backports/` | the backports' libraries; one set per process |
| `/Applications/<Name>.app` | an application; its `Frameworks` folder holds `app.frameworks` |
| `/usr/share/doc/<Package>/` | the licences named by `revenant.licenses` |
| `/System/Library/LaunchDaemons/` | in an emulated image, the only folder iOS 6's launchd reads |
| `~/.revenant/dyld/<release>/` | the shared caches and library folders the import check reads |
| `~/.revenant/firmware/` | the firmware catalogue, the fetched system images, and root filesystems unpacked by `xmake firmware rootfs` |
| `~/.revenant/emulator/golden.noindex/` | golden images of emulated devices |
