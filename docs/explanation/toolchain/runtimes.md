# Runtimes and backports: why they are built as they are

The packages that a port carries into its program are runtimes (the C++ and Swift libraries) and backports (the Objective-C and Swift APIs later releases added). Both are built for one minimum release, and both must cope with the release the device actually runs. The decisions below follow from that. For what each package is and how to name it, see the [packages reference](../../reference/toolchain/packages.md).

## Each package carries its own C++ runtime

`libcxx` is a shared pair, libc++ and libc++abi, and each package that needs it carries its own copy in `/usr/lib/revenant/<Package>/`. The reason is the minimum release. libc++ below iOS 4.2 does not re-export libc++abi, so an image linked against a later build binds those symbols to libc++, and nothing works. Each package's copy therefore matches the release its images are built for.

Two copies in one process keep separate thread-local storage and separate exception state. That is the boundary between packages, and it is deliberate: two tweaks in SpringBoard are two programs for this purpose.

`operator new` and `operator delete` stay with the package too. libc++abi defines them as ordinary symbols, so the package's images and its libc++ bind them to the package's own runtime, and dyld's coalescing of weak definitions does not pick the system's. Without this, dyld bound the first inserted image's uses to libstdc++, whose allocation failure is thrown on iOS 5 and 6 as a `GNUCC++` exception that Revenant's libc++abi can only catch as `catch (...)`. A failed allocation in a tweak now throws the `std::bad_alloc` its own `catch` names.

## Shared state is one copy per process

Some state must be shared by every image in a process, and for those the runtime exports one copy that every image binds to, re-exported by libc++.

- **Emulated thread-local storage.** Before iOS 9 on 32-bit and iOS 8 on arm64, dyld does not read `__thread_vars`, so `-femulated-tls` is added and a thread-local variable lives behind a pthread key through `__emutls_get_address`. Both that entry point and `__cxa_thread_atexit` come from the one libc++abi. A copy in each image would number the variables on its own, and two images would then read each other's storage.
- **The atomic library calls.** A wide `std::atomic` compiles to `__atomic_load` and its siblings. Below iOS 7 libSystem lacks them, so libc++abi exports compiler-rt's implementation, one copy for the process. It picks the lock for a memory location from a table, and two tables would guard the same memory with different locks.
- **The unfair locks.** The waiters of an `os_unfair_lock` and the unlock that wakes them meet in one table. A `Mutex` from the Synchronization library is inlined into every image that locks it, so two images take the same lock and must reach one copy of the wake-up. The word the lock keeps is that copy's own format: the owner's Mach thread port name with the low bit set, which a waiter clears. Below iOS 10 nothing else reads the word; from iOS 10 the system's own implementation is called instead.

The `libcxx` recipe refuses a runtime that does not export these below the release they arrived in, or that exports them at or above it, where the system's own must be used.

## What the compatibility shims are for

`apple-compat` holds what a current library calls and an old release does not have, as hidden definitions linked into each image that calls them. Where a header can rename the call, the shim has a renamed name (`clock_gettime`, `dispatch_get_global_queue`); where the compiler emits the call itself, the shim has the name the compiler uses. Nothing is force-included: a shim's header brings its system header with it, and a target names the calls it renames.

`dispatch_get_global_queue` is in the list for a particular reason. Every release exports it, but before iOS 8 it took a priority and answers NULL for a class of service. A caller that hands it a class renames it, and the shim maps the class to the priority it stands for.

`dispatch_block_create` and its family are a close copy of what libdispatch of iOS 8 does, since `DispatchWorkItem` is built on them. Two things are left out, and say so. A release has no classes of service and no vouchers, so the flags that name them are accepted and change nothing. The release's `dispatch_async` cannot read a block's flags, so `DISPATCH_BLOCK_BARRIER` is honoured by `apple-compat`'s own `revenant_dispatch_async`, `_sync`, `_group_async`, `_group_notify`, `_after` and `_source_set_event_handler`, which submit such a block as a barrier, as libdispatch of iOS 10 does. A source's cancellation and registration handlers are set through the release's own calls, and run as ordinary blocks.

## Swift is built from source, for the port's release

`revenant@swift` is the Swift compiler of a release, built from the sources of its own tag: swift, swiftlang's LLVM, cmark, swift-syntax, the string-processing library, and the driver with its packages, each pinned to the commit its tag named. Two changes make it usable on an old iOS.

- The frontend takes `-bundled-swift-runtime`. The runtime ships with the program, so the features of this Swift release are available at any deployment target. The SDK's own availability is still checked, and the flag is written into a module interface, so a reader compiles it the same way.
- The driver stops refusing a deployment target below iOS 7, which it had as its own minimum.

Only `revenant@swift` is used by a port. A compiled Swift module loads only in the compiler that wrote it, and the Command Line Tools' `swiftc` changes with macOS.

The runtime is built for the port's architecture and oldest release, from the same sources. Three changes are made to its sources: a class the runtime instantiates is realized by a method lookup where `objc_readClassPair` (iOS 8) is absent; a deadline is handed to libdispatch as a duration where `dispatch_time_t` does not say which clock it counts (before iOS 12), which also avoids a fixed timebase the runtime assumes on ARM; and the Synchronization and Observation libraries name `os_unfair_lock_lock` by symbol instead of importing `os/lock.h`, whose declaration carries iOS 10. Its availability macros are rewritten for the same reason the frontend flag exists.

### The Objective-C floor is iOS 6.0

With Objective-C interoperation, a Swift class marks itself with the low bit of its `data` word. iOS 6.0's Objective-C runtime masks that bit off when it reads the word; iOS 5.1.1's does not, reads the read-only data one byte off, and follows a wild pointer at the first class it realizes. So the runtime's floor is iOS 6.0. Below it the runtime would have to register no standard-library class with Objective-C, which gives up the Foundation bridges, or be adapted to that older runtime. Embedded Swift registers nothing with Objective-C, and is not bound by this floor.

### Library evolution is off by default

Without library evolution a client's class does not need the metadata update of iOS 12's Objective-C runtime, so it works on iOS 6. The price is that Swift modules built by different builds of the runtime do not mix in one image, and the modules are not a stable ABI. The package's hash enforces that everything is compiled together. Two packages do not hand Swift types across their boundary, which is the same line libc++ draws.

A program that an SDK's Swift compiled and that binds to Apple's resilient symbols by name needs `library_evolution`, the other build of the runtime. It is a different package, with its own shared-runtime name.

### Embedded Swift

Embedded Swift is the subset of the language without a runtime library of its own: classes, structures, protocols, generics, closures, `any` existentials, `throws`, arrays, dictionaries and strings, with no Objective-C interoperation, reflection, `Codable` or `async`. The result loads nothing but libSystem. C calls it through `@_cdecl` functions, and a `main.swift` is the entry point. The rule has swiftc write LLVM bitcode and clang make the object, because the LLVM inside Swift 6.4 loads the stack guard of armv7 code through an absolute address, which loses PIE for an executable that has such text relocations.

### The templates are expanded in Lua

The runtime's `.gyb` templates, and Embedded Swift's module and Combine's, are expanded by `modules/gyb`, a port of Swift's `gyb.py` to Lua, because no Python runs in the build. An interpreter covers the Python its code blocks use, down to float formatting, arbitrary-precision integers and the Mersenne Twister of `random.Random`. A construct it does not implement raises an error rather than being guessed at.

## Backports: the newest behaviour, and absence where it is unsafe

A backport makes an API that a later release added work on the release the port runs on. Its policy is set out in [the platform](../platform.md#the-backports); the choices below are how it is carried out.

**Each framework is one library, built for one release.** There are no bands: `backports_min_ios` is the only minimum, and a library is built for the release its imports are checked against. Where the system has a member of its own, the library does not add it, so a newer release never holds two classes of one name. The reason is that two copies of a class would be two classes. The backports are one per process for the same reason.

**The newest behaviour is carried.** Where a later release corrected a number, the corrected one is used. `NSUnitMass`'s stone is the plain case: iOS 10 converts a stone by 0.157473, the reciprocal of the 6.35029 it should be, and a program that asks for stones is asking for stones. Each class's facts say what was read, from which library and release, and what was left out on purpose.

**Absent is the default.** An API the library does not carry answers `respondsToSelector:` with NO, so an application that asks first keeps running. The alternative, an implementation that quietly does nothing, is reserved for places where doing nothing is a safe reading, such as an effect the release cannot draw. Wherever quiet inaction would corrupt data or mislead, the API is absent: security, saving, permissions and the network. An application that is told it is unsupported can handle that; one that is lied to cannot.

**Methods added to an existing class are categories.** The link moves them from `__objc_catlist` to `__DATA,__port_catlist`, where the runtime does not attach them. The library's initialiser adds each method, property and protocol only to a class that does not respond to it. It reads the method lists rather than calling `class_getInstanceMethod`, which on iOS 6 runs `+initialize` while UIKit is still loading.

**A lowered API keeps `#available` real.** A port that needs an API newer than its release takes the port's headers, not the compiler's `-disable-availability-checking`. That flag turns every `#available(iOS N, *)` into true, so a check written correctly is taken on a release that lacks the API, and the call fails there. With the port's headers only the APIs the backports implement are lowered, and every other check stays a real test.

**A lowered call finds its implementation only where its library is loaded.** A message to a library that is not there is an unrecognised selector at run time, not a link error, so the rule names the library a port must carry.

The weak imports of a backport have their own check. A backport built for a later release sees `_OBJC_CLASS_$_` references that bind to the backports library, but only when the library is linked before the system's; the import check refuses a weak import bound to a system library that lacks the symbol while a library of the build exports it. That sign means a link put a framework first.
