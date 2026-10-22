# Write a port

A port is an ordinary xmake project that includes the toolchain. This tutorial builds one from an empty directory: the project, how to build and package it, how to reach a phone, and how to take in the frameworks and runtimes it needs. The names and values are in the [rules reference](../../reference/toolchain/rules.md) and the [commands reference](../../reference/toolchain/commands.md).

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
    on_config(function () import("@addon.revenant.binding", {anonymous = true}).check() end)

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

The toolchain binds a target through the revenant rule it names, so an iphoneos target that names none would build without the revenant toolchain. The `on_config` line in the example makes that a configuration error: it names each iphoneos target that no revenant rule binds, and the configure fails until each one names a rule. Keep it in the project's main `xmake.lua`; xmake runs `on_config` only there, not from an included file.

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

`xmake deb` builds each slice for the release its architecture first runs, merges the bundles itself (every file
but a `.plist` has to be the same in every slice), and checks the merged binaries. Pin `MinimumOSVersion` in the
plist. A slice built without its shared cache under `~/.revenant/dyld` is said to be unchecked.

## Frameworks and runtimes

A port takes a package by its name and an alias, adds it to the target, and names its libraries where a tweak or daemon loads them:

    add_deps("UIKitBackports")

    target("example")
        add_rules("@addon/revenant/app")
        add_deps("FoundationBackports")

The Backport libraries are the component's own targets, and the package a program depends on for them is written by `./xmakew deb`; see [the packages reference](../../reference/toolchain/packages.md#backports). `revenant.libraries` is needed for the check to see the backport dylib as the build's own. Without it, a link fails with "these imports are not exported by the device's iOS", even though the package is there.

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

Combine is `revenant@combine`, the package of OpenCombine with our patches. It is built against the runtime and libcxx, so the port names it beside those:

    add_requires("revenant@combine", {alias = "combine"})

    target("example")
        add_packages("combine", "swift-runtime", "libcxx")

SwiftUI is not a package of this repository: its recipes were pins of it, and the target `SwiftUI` of `frameworks/SwiftUI` is built inside the checkout. A port outside the checkout takes SwiftUI from the packages that `xmake package` writes for our targets, as [the architecture](../../explanation/architecture.md) describes; that route is not yet verified for iOS.

A SwiftUI port takes the three packages as they are: the runtime has no `backports` variant. Combine's own weak import is answered by the `frameworks/Backports` targets, which the port links by `add_deps` where it uses Core Data. The runtime's weak imports are checked against `modules/apple/runtime_guards.lua`.

## Next

Checks, waivers and the libraries of a release are in [checks and waivers](../../guides/toolchain/checks.md).
