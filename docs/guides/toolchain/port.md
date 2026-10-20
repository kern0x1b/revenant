# Write a port

A port is an ordinary xmake project that includes the toolchain. This guide shows the project, how to build and package it, how to reach a phone, and how to take in the frameworks and runtimes it needs. The names and values are in the [rules reference](../../reference/toolchain/rules.md) and the [commands reference](../../reference/toolchain/commands.md).

## Machine

    brew install xmake llvm
    xcode-select --install

Then clone the repository. The toolchain needs no other install.

## The project

A minimal `xmake.lua` for a tweak:

    set_project("example")
    set_version("1.0.0")
    set_policy("package.requires_lock", true)

    add_repositories("revenant https://github.com/kern0x1b/revenant.git main")
    add_addons("revenant latest")
    set_config("apple_minimum", "6.0")
    includes("@addon/revenant/apple-ios")

    set_defaultplat("iphoneos")
    set_defaultarchs("iphoneos|armv7")

    target("example")
        add_rules("@addon/revenant/tweak")
        add_files("example.m")
        add_frameworks("Foundation")
        set_values("tweak.filter", "packaging/example.plist")
        set_values("revenant.control", "packaging/control")

`add_addons("revenant latest")` takes the newest release tag of the repository; pin a tag once one exists, so that a new release is an explicit change. Commit the `xmake-requires.lock` and `xmake-addons.lock` the build writes. A checkout nested inside another project, such as a worktree under the main checkout, builds with `xmake -P .`.

`apple_minimum` is the oldest release the port runs on. The toolchain refuses a release the architecture cannot run, and names the architectures that can: a port that asks for 2.0 on armv7 is told to build armv6.

Pick the target kind to match what the program is: a MobileSubstrate dylib (`tweak`), an executable in `/usr/libexec` (`daemon`), an application bundle (`app`), or a shared library an application bundles (`library`). The values each one reads are in the reference.

## Build, package and install

    xmake                                     build; every binary is checked as it links
    xmake deb                                 write build/<Package>_<Version>_<Architecture>.deb
    xmake device install                      the same, then install on the phone
    xmake device log [-s 30] [TEXT]           read the phone's log
    xmake device run COMMAND                  run a command on the phone

The phone is named in `device.env`, with `DEVICE_HOST`, `DEVICE_PORT`, `DEVICE_UDID` and `DEVICE_PASSWORD`. A port with several phones keeps `device.NAME.env` beside it and picks one with `-d NAME`, or with `REVENANT_DEVICE=NAME` for a whole shell. Keep `device.env` out of git: it is gitignored, and so are the other `device.*.env` names.

`xmake device claim` holds the phone for one session, so another session's commands on it are refused until the release or the expiry (default 30 minutes). `--holder` names the session, or `REVENANT_DEVICE_HOLDER` does it for a shell.

### Universal applications

An application that runs on more than one architecture names them:

    target("Example")
        add_rules("@addon/revenant/app")
        add_values("apple.architectures", "armv7", "arm64")
        set_values("app.plist-file", "packaging/Info.plist")

`xmake deb` builds each slice for the release its architecture first runs, merges the bundles with `lipo`, and checks the merged binaries. Every other file has to be the same in every slice, so pin `MinimumOSVersion` in the plist. A slice built without its shared cache under `~/.revenant/dyld` is said to be unchecked.

## Frameworks and runtimes

A port takes a package by its name and an alias, adds it to the target, and names its libraries where a tweak or daemon loads them:

    add_deps("UIKitBackports")

    target("example")
        add_rules("@addon/revenant/app")
        add_deps("FoundationBackports")

The `configs` choose which backport libraries are built; see [the packages reference](../../reference/toolchain/packages.md#backports). `revenant.libraries` is needed for the check to see the backport dylib as the build's own. Without it, a link fails with "these imports are not exported by the device's iOS", even though the package is there.

### Swift

A Swift target compiles with the `swift` rule, and the packages it needs are named beside it:

    add_requires("revenant@swift-runtime", {alias = "swift-runtime"})
    add_requires("revenant@libcxx", {alias = "libcxx"})

    target("example")
        add_rules("@addon/revenant/app")
        add_rules("@addon/revenant/swift")
        add_packages("swift-runtime", "libcxx")

A port that needs only the language core, with no runtime, requires `revenant@swift-embedded` instead and names it the same way. The `swift` rule refuses a project that requires both or neither. `swift.module` sets the module name, and `swift.flags` the flags.

### Combine and SwiftUI

Combine is `revenant@combine`, and SwiftUI is `revenant@swiftui-uikit`. Both are built against the runtime and libcxx, so the port names them beside those:

    add_requires("revenant@combine", {alias = "combine"})
    add_requires("revenant@swiftui-uikit", {alias = "swiftui"})

    target("example")
        add_packages("combine", "swiftui", "swift-runtime", "libcxx")

A SwiftUI port takes the `backports` variant of the three packages. Combine's own weak import is answered by the `frameworks/Backports` targets, which the port then carries with `coredata = true` where it uses Core Data. The runtime's weak imports are checked against `modules/apple/runtime_guards.lua`.

## Checks

A check is a target of its own. It runs a script or a program over the files it names, when those are staged or changed:

    target("lint-strings")
        add_rules("@addon/revenant/check")
        set_values("check.script", "scripts/lint-strings.sh")
        add_values("check.files", "src/**.m", "src/**.h")
        set_values("check.pass-files", true)

`xmake check` runs them; `xmake check --staged` and `xmake check --changed` run only those whose files are staged or changed. `xmake check --install-hook` makes the git pre-commit hook run the staged ones. A script that calls xmake again passes the task first: `xmake where -P DIR tdlib`, not `xmake -P DIR where`.

`xmake compile-commands [-o FILE] [TARGETS]` writes `compile_commands.json` for the named targets, for example the iOS ones without the host tests.

## Waivers

A check that the port cannot meet is waived by name, with the reason, and the reason is kept in the build:

    set_values("revenant.waive.pagezero", "why the executable's first segment is not at its place")

- `revenant.waive.weak-imports`: a weak import of a symbol the checked release lacks, which is refused when the image is released. Say why every call is guarded.
- `revenant.waive.input-minimum.<package>`: a package whose objects do not record the port's minimum release.
- `revenant.waive.<check>`: any other named check.

## Import checks need the release's libraries

The import check reads the system libraries of a release from `~/.revenant/dyld/<release>/`. When they are not held, the check offers to fetch them, and `-y` accepts:

    xmake firmware fetch 6.1.3                # the shared cache for the release, by hand
    xmake firmware list                       # what is held

`xmake firmware --device=iPhone3,1 rootfs 6.0` unpacks a device's root filesystem for the emulator. See [the emulator guide](emulate.md).
