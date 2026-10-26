# Why the toolchain is built this way

The toolchain lets an application written for a current SDK be built, checked and run for an old iOS: armv6 from iPhone OS 2.0 to 4.2.1, armv7 from 3.0, armv7s from iOS 6 and arm64 from iOS 7, with no Xcode. iOS 6 is the first target. The driver is meant to serve other old platforms as well, which is why it is a separate layer and not a set of patches to one port.

## Two halves

A port is an ordinary xmake project. The toolchain adds only what xmake does not know about these platforms, in two parts:

- an **addon**, `revenant`: the `apple-ios` toolchain, the target rules, the checks a binary must pass, the verbs that package and reach a phone or an emulator;
- a **package repository**: the SDK, the linker, the signer, the C and Swift runtimes, and the libraries that ports share, each named `revenant@<name>` and built from source.

Keeping the two apart means a port names what it needs by name and version, and a change to a runtime is a different package with its own install path. It also means the repository can be checked as a whole, without building a port.

## Why the compiler is clang from `llvm`

Xcode is not needed. The Command Line Tools supply only a few tools the toolchain still calls, `strip` among them; the compiler is clang 23, built by the `llvm` package with its own runtime. Using one compiler for every release means one set of behaviour to test, and the flags for an old release (`-mlinker-version`, emulated TLS, the minimum OS version) are the toolchain's to set rather than Xcode's to choose.

## Why the SDK is patched

The SDKs from iPhone OS 2 to iOS 6 carried start files that current SDKs no longer ship. Below iOS 7 an executable starts through Apple's `crt1.3.1.o`, and without that file ld64 would silently raise the executable's minimum to 7.0. The `iphoneos-sdk` package puts back what those SDKs carried: the start files, and `libgcc_s.1.tbd`, which lists the arithmetic helpers the releases exported. Its libSystem stubs are taken from an older SDK where the newest one has no hide markers at all. The result is the SDK the device's own libraries expect, not the one the newest Xcode would produce.

Newer SDKs also move classes and functions into private sub-frameworks and re-export them from the public umbrella, so a binding names a library iOS 6 does not have: `_OBJC_CLASS_$_CLLocation` names `_LocationEssentials`, where iOS 6 has `CoreLocation`. The lowering folds the exports of every re-exported library that the iOS 6 inventory lacks into the stub of the umbrella that re-exports it, and drops the re-export, so the symbol binds to a library the device has. The inventory is `toolchain/src/iphoneos-sdk/inventory/ios6.txt`, the install names both held iOS 6 caches (6.0 and 6.1.3) export. A symbol the device does not export at all still fails the import check, as before.

## Why ld64 is here

Apple's linker in Xcode 27 cannot link a 25 MB armv7 dylib: a Thumb branch reaches 16 MB, the call stubs sit after all the text, and the linker does not insert the branch islands that bridge the gap. ld64 does. Apple's linker writes an `LC_ENCRYPTION_INFO` load command into every armv7 dylib, and iOS 6 does not start an application whose MobileSubstrate tweak carries one: the tweak's constructor never runs, and there is no crash log. ld64 does not write it. So the toolchain builds ld64 from cctools-port with libtapi, which reads the SDK's `.tbd` stubs, and links every armv7 binary with it.

## Why checks run where a binary is linked

A binary built for a current SDK can load on the wrong release and fail on the device only when it reaches the missing call, which may be a crash with no hint of the cause. So each binary is checked as it is linked, against the device's own libraries:

- every import is looked up where dyld looks for it, in the library its binding names and in what that library re-exports, so a symbol the device exports only from another library is refused;
- the reference is the release's shared cache, not the SDK's stubs, because the stubs describe what Apple declared and the cache says what the device has;
- a call the compiler wrote itself (ARC entry points, the block runtime, emulated TLS, the wide atomics) is refused when its runtime is missing, since no version check can stand in front of it;
- a weak import of something the release lacks is a warning, because a guarded call is correct; it becomes an error for a release's own image, unless the port says why every call is guarded.

Each check has a name, so a port that cannot meet one says so, with a reason, rather than having it switched off. See [the rules reference](../../reference/toolchain/rules.md#checks-on-every-linked-binary).

## Why the import check fetches firmware

The check needs the release's libraries, and the SDK does not contain them. The `firmware` verb fetches only the system image of the release from Apple's servers, reads the shared cache out of it, and keeps the result under `.cache/dyld/`. Those files cannot be made again from the repository, so they are fetched once and kept, and a missing one is offered for fetch rather than guessed.

## Why there is an emulator

Testing on an iPhone 4S or an iPad 2 needs a device at hand, and a device that is held by one session is not free for another. `xmake emulate` boots a firmware's own userland on an emulated XNU on macOS arm64. A port is installed into a copy of the image, its maintainer scripts run against it as dpkg runs them, and it is started through SpringBoard or as a process. The verdict says whether it passed, failed, timed out, crashed, or whether the boot itself was blocked, and names where.

The emulator is one to two orders of magnitude slower than the device, and the guest measures its own watchdogs and RPC deadlines in wall-clock seconds. A boot that runs at the device's pace kills its own daemons. So the toolchain runs the guest's clock slower.

### The guest clock

`--scale` is how many host seconds one guest second takes; it defaults to 10. The scale is a property of the run, not a hidden correction: it is in the emulator's log, in the verdict, and in the line a run prints. A verdict carries `guest_seconds` (the guest's own clock) beside `host_seconds` (the wall-clock length of the boot), so a test that measures time can convert the two. A target that measures time itself sets `emulate.timing` to `strict`, and the run then refuses any scale but 1 rather than hand it a converted number.

The default was measured on an iPhone 4,1 running iOS 6.1.3 over 11 minutes of boot. At a scale of 1, `backboardd` killed six processes, Setup and MobileMail among them, and SpringBoard restarted five times. At 5 and at 10 those kills were gone. Everything the guest reads from its clock is scaled together: `mach_absolute_time`, `gettimeofday`, dispatch timers and kevent deadlines all come from the one virtual clock the emulator paces.

### What a blocked boot says

A guest that kills a process writes a CrashReporter report, and the toolchain copies it beside the verdict; the reason the first report names is part of a blocked boot's verdict line. A boot that ends while a thread is still waiting for the reply to a request it sent is a hole in the emulation, not a slow guest, so the verdict names the request, the process, and how long it waited. A daemon parked on its service port is not that, and is not reported.

## Why a debugger is in the toolchain

No debugger on an arm64 host talks to an armv7 guest. `xmake emulate debug` therefore speaks the debugger's protocol itself, starts the program as the guest's first process so that nothing else is in the report, and prints where it stopped. The frames follow the frame pointer chain, named by dyld's own list of images, so the library names are the guest's and not the host's.

## Why sessions wait for the phone

Several sessions can run against one phone. `xmake device claim` holds it for one holder for a time; every other holder's command on it is refused until the release or the expiry, so one session's install is not overwritten by another's. The holder is named by `--holder` or `REVENANT_DEVICE_HOLDER`, so a shell can carry it.
