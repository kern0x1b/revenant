# The corpus and the benchmark

`tests/` holds the translator's own regression programs and `tests/perf/` its benchmark. Their sources are C, Objective-C,
assembly and Swift. The steps that build, translate and check them are Lua run by xmake: a `check.lua` or `build.lua`
beside the sources, and the shared parts in `recompiler/tools/` (`env.lua`, `corpus.lua`, `translate.lua`, `macho.lua`).

## Running

From the revenant root, after `./xmakew f -P . -y` and `./xmakew build -P . xlate xlgen`:

```sh
./xmakew test -P . 'recompiler_corpus/*'
./xmakew build -P . recompiler_cxxinit recompiler_refrepro recompiler_blockid recompiler_devtime
```

`recompiler_corpus` runs the host part of every check it declares: jumptable, tsdscan, tsdguard,
int128, weakimport, lse, llsc, exceptions, objectsplit and hostbridges; `classpair` and `ordinal` are the device group's, which also runs the
device part of `exceptions` and `hostbridges`. Their output goes to the
target's build folder (`build/.gens/recompiler_corpus/.../tests/<name>`). The four
build targets each leave an `.app` or an executable in their own target folder.

A check that also has a device part is run by hand, with the output folder as its argument:

```sh
./xmakew l -P . recompiler/tests/weakimport/check.lua <out>
./xmakew l -P . recompiler/tests/classpair/check.lua <out>
./xmakew l -P . recompiler/tests/exceptions/check.lua <out>
./xmakew l -P . recompiler/tests/hostbridges/check.lua <out>
./xmakew l -P . recompiler/tests/swiftconformance/check.lua <out>
./xmakew l -P . recompiler/tests/swiftobjc/check.lua <out>
```

These need a claimed device (the skill `device`): `REVENANT_DEVICE_HOLDER` and `REVENANT_DEVICE`
exported and the claim held. They reach the device through Revenant's `device` module. Without an argument, output goes
to `build/recompiler/corpus/<name>`.

## What each check proves

### jumptable

A control for `JumpTables::Resolve` in `src/xlate/xlate.cpp`. At build time, xlate finds where a register-indirect
branch can go: it reads the guest's byte table for every index the branch's guards let through.

The demo crashed past `_DictionaryStorage.allocate` with "jump to an address that does not start a translated
function". The cause was a missed target in libswiftCore's demangler (`getUnspecialized`):

- Its table dispatch has two guards, `(kind - 13) unsigned >= 6` and `kind <= 0x10f`, so the indices that reach the
  table read are {0..12} and {19..271}, with a gap between them.
- The old code took the first run, 0..12. It stopped the whole scan at index 13, on the belief that the domain is one
  contiguous range.
- Everything reachable only through 19..271 was never a candidate, and xlate said nothing about it.

`dispatch.s` reproduces that shape with the exact instructions. A C switch is not reliably lowered to them. Kinds 2
and 3 are diverted before the table is read, so the domain is {0, 1} and {4, 5}. There are four distinct case bodies;
the old code found two.

The check builds the libc-free driver `main.c`, feeds it to xlate, and requires the exact reported count of four
targets. Requiring "not zero" would let a partial regression (two or three targets) pass. This is host only: it
checks xlate's build-time discovery, not the guest at run time.

A second binary, `inline.c` with `inline.s`, covers a jump table that sits inside `__text`. ld64 lists such a table's
symbol in `LC_FUNCTION_STARTS` as if it were a function, and the words of a table are data: a `udf`, or an
address, that is not an instruction. xlate used to lift each word as a function and count it as a failure (the
image linked from the 319 objects of Google's reCAPTCHA Enterprise SDK had three: "3 failures", now
"0 failures, 3 jump table data words"). `JumpTables` now keeps the words of every table it resolved, and the lift
loop skips a listed start that lies in one and counts it as `table data` in the summary line. The check requires the
exact line `4 jump table targets, 0 failures, 1 jump table data words`.

### lse

A control for rellume's lifting of the ARMv8.1 LSE atomics: LDADD, LDCLR, LDEOR, LDSET, LDSMAX, LDSMIN, LDUMAX,
LDUMIN, SWP and CAS.

`main.c` defines 200 functions, one per operation, access width (8, 16, 32 and 64 bits) and memory order (relaxed,
acquire, release, acq_rel and seq_cst). It is built for arm64 with `-march=armv8.1-a`, so clang emits each as one LSE
instruction rather than an exclusive loop. The check proves three things, all on the host:

1. The arm64 binary carries the expected form in every function: the right mnemonic, the right ordering and size
   suffixes, and `w` or `x` registers.
2. xlate lifts every function, and each lifted function holds exactly one `atomicrmw` or `cmpxchg`, with the
   operation, the integer width, the alignment and the LLVM ordering its instruction asks for. A and L together
   become `acq_rel`, which is also what seq_cst compiles to.
3. The lifted code, compiled for armv7 with the flags `recompiler/tools/translate.lua` uses, carries the byte, halfword, word and
   doubleword exclusive pairs the atomics are lowered to. The program is libc-free and has no Objective-C or blocks,
   which the runtime a full translation links expects, so the check stops at the lifted object.

The lifted IR is checked, not only xlate's failure count. Without the LSE cases, xlate reported 180 of the 200 functions
as undecodable: those whose atomic is the first instruction. The 20 `and` functions start with an `mvn`. rellume
lifted each of them up to the atomic and ended it with an exit to that instruction's guest address. xlate counted
those as lifted, and the program would only fail when it got there.

### llsc

A control for rellume's lifting of the exclusive loads and stores, the loop clang emits for an atomic when the target
has no LSE: `LDXR`, `LDAXR`, `STXR`, `STLXR` and `CLREX`, in the byte, halfword, word and doubleword forms.

`main.c` defines 160 functions: add, and, xor, or, exchange, signed max and unsigned min, and compare-and-swap, in each
access width and each of the five memory orders. It is built with `-march=armv8-a`, so each is an exclusive loop.
The check proves four things on the host:

1. Every function carries the pair its width and order ask for (`ldxr` or `ldaxr`, `stxr` or `stlxr`, with the `b` or
   `h` suffix).
2. xlate leaves no instruction unlifted (`coverage: 0 of ...`, `clrex` among them) and lifts every function.
3. The exclusive monitor is part of the state header (`EXCL_ADDR` and `EXCL_VAL`), and in each lifted function every
   exclusive load is an atomic load of its width (acquire for `LDAXR`) and every exclusive store is a `cmpxchg` that
   expects the loaded value, release for `STLXR`, with no `atomicrmw`. A plain store with a status register of 0,
   which is what `STXR` was lifted to before, has none of these.
4. The lifted code, compiled for armv7, carries the byte, halfword, word and doubleword exclusive pairs.

The monitor remembers the address and the value an exclusive load saw. `STXR` succeeds only when the address is the
recorded one and the `cmpxchg` still finds the recorded value, so a thread that wrote in between makes it fail and
the loop retry. A store that finds the same value written back by another thread succeeds, as it does in a user-mode
emulator; the loops compilers emit are value-based and tolerate it. `LDXP` and `STXP` still lift as a plain load and
store, because a 128-bit `cmpxchg` has no armv7 lowering.

### exceptions

A program of Objective-C and C++ (`main.m`, `guarded.mm`) that throws and catches across guest frames. It covers:

- an `NSException` raised in a guest frame (`@throw`) and one raised by the host (`-objectAtIndex:` out of range), both
  caught by a guest `@try` two guest frames up, through a C++ frame whose destructors must run;
- `@catch` of a class the guest defines (a subclass of `NSException`), of `NSException`, of `id` (a thrown string), and
  `@finally`;
- `@throw;` rethrow, and a C++ `catch (...)` that takes an Objective-C exception;
- an exception raised in a block the host calls (`enumerateObjectsUsingBlock:`), so the unwind crosses host frames;
- callee-saved registers live across a catch, a catch followed by a tail call, a catch on a second thread;
- loops that catch 2000 exceptions, one with two `@try` regions in the loop body (each landing pad continues into the
  other), which kept a stack frame per catch before landing pads returned to a loop.

The check builds the program for this Mac and for arm64 iOS. The Mac's output is `tests/data/exceptions/expected.txt`.
On the host xlate must report at least 20 call sites unwinding to at least 6 landing pads, with no "left as plain
calls" line and no unreadable LSDA, the lifted module must carry `invoke`, `landingpad` and both the Objective-C and
the C++ personality, and the translated binary must import `_Unwind_SjLj_Register`. The device part runs the translated
binary and compares its output with the Mac's. The program takes the number of loop rounds as its argument (2000
by default), so a probe can run it deeper by hand.

### hostbridges

A program (`main.m`) that calls the host functions whose guest and host layouts differ or whose argument is an `IMP`:

- `sscanf` and `vsscanf` with `int`, `long`, `long long`, `size_t`, `double`, `float`, `short`, `signed char`, `%x`,
  `%p`, `%c`, `%s`, `%n` and `%ln`, a conversion that fails half way (the later variables stay untouched), empty input,
  a suppressed conversion;
- `getaddrinfo` for a numeric IPv4 host with a service, for IPv6, for a name with `AI_NUMERICHOST` (status 8) and with
  `AI_PASSIVE`, walking the list and `freeaddrinfo`;
- `class_copyMethodList` of a guest class, its metaclass, a guest subclass and `NSObject`, sorted by selector;
- `IMP`s both ways: a guest method's `IMP` called by the guest on a guest instance and on a subclass instance; host
  `IMP`s of a concrete `NSString` class called by the guest; the `NSObject` `-isKindOfClass:` `IMP` called on an instance
  of a guest class that overrides it; `imp_implementationWithBlock` with a captured `__block` variable, added with
  `class_addMethod` and called by a message send, `imp_getBlock` and `imp_removeBlock`; a C function added with
  `class_addMethod`; `class_replaceMethod` and `method_setImplementation` with the old `IMP` called afterwards.

The check builds the program for this Mac and compares its output with `tests/data/hostbridges/expected.txt`, translates
the arm64 build (which fails on any import without a bridge) and requires that the program imports each of the bridged
functions. The device part runs the translated binary and compares its output with the Mac's.

### objectsplit

A synthetic module of 6500 functions, each with 120 `invoke`s into one SjLj cleanup landing pad (15 MB of bitcode, about
20 MB of armv7 code). It is the swiftobjc regression in miniature: the guest `libswiftCore` with its exception edges
split into pieces of 14 to 16 MB of bitcode and every piece failed with "can not encode offset ... in resulting
scattered relocation", because an armv7 Mach-O scattered relocation, which the SjLj frame of a function with a landing
pad needs for the label difference between `__text` and `__gcc_except_tab`, addresses 24 bits of a section: nothing past
16 MB of `__text` can carry one.

The check compiles the module as one object and requires that to fail with that message, so that the module keeps being
too big. Then `compile_lifted` of `translate.lua` compiles it with its own piece size: at least three objects, each
smaller than 16 MB, and every function defined once across them. The objects are compiled with `-O0` to keep the check
at about a minute; the limit is on the size of an object, and `-O0` code is bigger than `-O2` code.

### tsdscan

A control for xlate's build-time TSD offset scan (`src/xlate/tsd_scan.cpp`). xlate refuses to lift an image that reads
`TPIDRRO_EL0` at an offset nobody has audited. Two builds of `main.c` are fed to xlate directly; neither is run:

1. `TSD_OFFSET=0x358`, Swift's `__PTK_FRAMEWORK_SWIFT_KEY7`. This is the one offset that `src/runtime/runtime.c`'s fake TSD
   block is measured and sized for, so xlate must accept the image.
2. `TSD_OFFSET=0x40`, an offset no guest has ever been measured touching. xlate must refuse it. The error must name the
   offset and each of the three cases by its function:
   - `read_tsd_slot`, a straight line;
   - `dead_path_clobber`, a clobber on one arm of a branch;
   - `callee_reads_tsd`, the base crossing a call in a callee-saved register.

   An address-ordered, per-function sweep missed the last two, so a scanner that catches only the first must fail.

The logs and binaries are removed before each run. A failed build would otherwise leave the previous run's output in
place, and it would be read as this run's answer.

### tsdguard

Proves the page-protection scheme of `src/runtime/xl_tsd_guard.h` on the build host. That header is the runtime half of the
`TPIDRRO_EL0` workaround. mmap, mprotect and SIGSEGV are POSIX, so `main.c` is compiled for the host and run directly. There
is no device, lift or translation.

It proves the arithmetic at this machine's page size, which `main.c` prints: 16384 on Apple Silicon. The 4 KiB device
case rests on `xl_tsd_guard.h` reading the page size from `sysconf`. Each check in `main.c` forks with its own `alarm()`,
a bounded parent-side wait and a SIGKILL fallback, after a real hang on a device. The outer 60-second limit in
`check.lua` is a second, independent belt: if it ever fires, `main.c`'s own bounding failed.

### int128

Checks `src/runtime/int128.c` (`__udivti3`, `__umodti3`, `__divti3`, `__modti3`) against a 128-bit reference in Lua. The
inputs are:

- edge values, and every pair of them;
- random values of widths 1, 8, 31, 32, 63, 64, 65, 100, 127 and 128 bits, from a fixed seed.

`INT128_MIN / -1` is left out, because it overflows in C. The reference runs its own self-test first. The driver
`driver.c` is built for the host and fed the cases on stdin. An optional second argument sets the number of random
values (3000 by default).

### ordinal

A guest image that defines a name a host library also has (`NSString`, `getpid`) answers a bind only when the bind
names that image. This holds for each kind of bind: the superclass pointer, a class reference and a call stub.

- The class reference and the stub are not in the manifest. They are resolved when the image is lifted.
  - A bind that a guest image answers leaves no reference to the host symbol in the lifted module.
  - A bind that no guest image answers is a passthrough: a declaration of the host symbol in the module.
- A call stub to libSystem's `getpid` has no answer in a guest image that merely defines `getpid`, and `--strict` says
  so.
- Two images with one file name are told apart by install name. A bind takes the image whose install name it spells,
  not the one that comes first.
- Refused, each with both files named:
  - two images that are the same library;
  - one library named twice in `--replaces`;
  - a `--replaces` entry that is an image's own install name.
- A bind to a system path is the host's library unless `--replaces` says a guest image stands for it.
- A library that an image re-exports whole (`LC_REEXPORT_DYLIB`) is answered by that image, and counts as answered in
  the list `recompiler/tools/translate.lua` reads.
- `recompiler/tools/translate.lua` takes the symbols that no host library supplies from xlate's own answers, not from what the images
  export. An app that binds the host's `NSString` next to an embedded image that defines its own still needs `NSString`
  bridged. An app that binds the embedded image's `NSString` does not.

The image indices in xlate's JSON are 1-based in Lua: the app, libfrombx, `a/libcoll` (the app's link), then
`b/libcoll` (libfrombx's).

### weakimport

Weak imports, judged both by what `--strict` says and by what the translated program does.

1. Host part. A call stub is weak or strong by its own image. A library that checks for `getppid` does not excuse an
   executable that calls it.
   - An image with bind entries for its stubs says whether each stub is weak in two places.
   - Only an image without bind entries depends on the stub's own symbol-table flag alone. Such an image is one pulled
     out of a shared cache; `macho.unbind` makes one by zeroing the bind, weak-bind and lazy-bind ranges of
     `LC_DYLD_INFO`.
   - The unbound executable is refused for its stub's flag alone. The unbound library's weak stub stays weak by its
     own flag.
2. Device part. The program runs twice on the iPad 2: once built natively for iOS 6, once translated from arm64. Both
   must print `expected.txt`. The outputs are kept as `run-native.txt` and `run.txt`.

### classpair

Classes that the Swift runtime lays out, and the calls that hand them to libobjc. `main.c` has the story, and the
README's "Classes the Swift runtime lays out" has the design.

1. Host part. `main.c` is built for macOS, where objc4 is the real thing, and run. Its output must stay `expected.txt`.
2. Host part, from xlate's manifest of the translation itself. `XLPairListedOverClsro` is a `__objc_classlist` class
   whose immediate superclass is laid out only in `__objc_clsrolist`. It must be moved to the guest layout.
   - `SplitGuestLayoutClasses` once walked ancestors only among `__objc_classlist` classes, so this class was silently
     kept at host layout.
   - The manifest's own safety check misses this case for the same reason.
3. Device part. The program is translated from arm64 and run on the iPad 2, and must print what macOS printed.
   - iOS 6's libobjc has none of `objc_readClassPair`, `_objc_realizeClassFromSwift` and
     `objc_setHook_lazyClassNamer`, so the program cannot be built for iOS 6 natively. The macOS run is the oracle.

The arm64 input is linked with Revenant's `ld64`. The linker of Xcode 15 and later drops `__objc_clsrolist`, which Swift
binaries carry.

### swiftconformance (device only)

A control for the `_dyld_register_func_for_add_image` bridge in `src/runtime/bridge.m`, the fix for the
`_DictionaryStorage.allocate` crash.

In `fixture.swift`, `Widget`'s conformance to `Hashable` is a `__swift5_proto` record in the guest image itself. The
Swift runtime can find that record only if something tells it the image exists and feeds it the image's sections,
which is what the bridge does. At run time, `x is Hashable` prints `hashable` or `not-hashable`.

The check translates the fixture twice. The normal build must print `hashable`; the control, built with
`-DXL_TEST_NO_DYLD_IMAGE_BRIDGE=1`, must print `not-hashable`.

The fixture is compiled with Revenant's from-source Swift toolchain (`revenant@swift`), not Xcode's Command Line Tools:

- The CLT `swiftc` cannot cross-compile for `arm64-apple-ios`. It fails with "Cannot read legacy layout file ...
  layouts-arm64.yaml", because CLT ships `lib/swift/macosx/` only.
- That file is not Apple-internal. It is in the open-source Swift tree at
  `stdlib/toolchain/legacy_layouts/iphoneos/layouts-arm64.yaml`, and an install of `revenant@swift` that kept its source
  cache carries it.
  - The check looks for such an install by what it contains.
  - It never takes the first match, because several hashed installs of one version can exist.
- Two flags close the gap:
  - `-Xfrontend -read-legacy-type-info-path=<that file>`;
  - `-runtime-compatibility-version none`, which skips auto-linking the `swiftCompatibilityNN` back-deploy shims. That
    resource tree lacks them, and the fixture does not need them.

The fixture links only libSystem and `@rpath/libswiftCore.dylib`. libswiftCore itself reaches into libc++ and
libc++abi on the conformance path, the demangler among them. Without those as guest images, the program crashes on the
device with "call to an address without translated code" before main prints anything.

So the fixture is translated like the demo:

- with libswiftCore, libc++ and libc++abi from the folder in `XL_SWIFTCONFORMANCE_LIBS`;
- with `XL_REPLACES` mapping `/usr/lib/libc++.1.dylib` to the guest libc++.

`XL_SWIFTCONFORMANCE_ALSO_DEMO=1` adds a second, independent confirmation, off by default because it costs two more
full translations. It also translates the real demo (`XL_SWIFTCONFORMANCE_DEMO`), normally and with the bridge
compiled out. The control must crash with exit 139, and the normal build must not.

### swiftobjc (device only)

A control for the twin scheme of `src/runtime/swift_classes.m`: Swift classes that inherit from a class of the host's
Objective-C runtime (here `NSObject`), translated with `XL_SWIFT_HOST_ANCESTORS=1` (`--swift-host-ancestors` of xlate).

The fixture has three classes: `Client`, an `NSObject` subclass with stored properties (a `String`, an `[String]`, an
optional reference, a closure); `Sub`, a final subclass of `Client` that overrides `bump` and calls `super`; and
`Token`, a final `NSObject` subclass whose Swift `deinit` prints. It prints `ok <name>` or `FAIL <name>` for 21
checks, among them:

- construction through `Client()` (the Swift `init` of an ObjC ancestor runs `objc_msgSendSuper2` with the class from
  `swift_getObjectType`, which must be the guest's own metadata);
- Swift and `@objc` dispatch, `super` calls through the guest vtable, and an `as?` cast of an `AnyObject`;
- `respondsToSelector:`, `performSelector:` (of a method that returns an object) and `isKindOfClass:` from the host side;
- the Swift `deinit` of `Token` reached through the host's `dealloc`, and the release of the stored properties of a
  `Client` and of a `Sub` when they die (the `.cxx_destruct` of the guest class, which the host's libobjc does not run
  for a class it did not read from an image);
- an instance the host allocates with `class_createInstance` (no `objc_alloc` on the way, so the copy of the Swift part
  of the class must be current; no `init` runs, so only its class is used) and one made by `NSObject.Type.init()`,
  which is then dispatched to and cast;
- `_typeName` of the classes. `String(describing:)` of a class is not covered: it goes through `Mirror`, which aborts
  in the guest `libswiftCore` (see [the work split](../../explanation/recaptcha-work-split.md)).

The check wants every name `ok`, no `FAIL`, the `deinit` line, and exit 0.

It needs the arm64 runtime, so `XL_SWIFTOBJC_LIBS` names the folder with `libswiftCore.dylib` (the one that
`revenant@swift-runtime` built for arm64, which carries `-DSWIFT_CLASS_IS_SWIFT_MASK=1ULL`), `libc++.1.dylib` and
`libc++abi.1.dylib`. The fixture is compiled like swiftconformance's, for iOS 12.0 with the legacy type info: that
target marks a Swift class with bit 0 of the class data, the bit the guest's libswiftCore tests. A class compiled for
iOS 12.2 or later (bit 1) is accepted too, because the runtime rewrites that bit when it sets the class up.

### library (device part by hand)

A control for [library mode](../../explanation/recompiler/library-mode.md): an app that loads a translated library into
its own process, next to a heap of its own size. `tests/library/check.lua` has two variants, `objc` (the default) and
`swift`, one fixture each with the same public API: `RCFClient` (`+clientWithSeed:`, `-bump`, `-seed`,
`-describedLength`, `-hostBundle`, `-tokenForAction:`, `-executeWithAction:completion:`) and `RCFToken`. Nothing in the
API is a string, because a Swift `String` that crosses an Objective-C signature goes through the Foundation overlay,
which the guest does not have yet; the strings stay inside the library (`describedLength` builds one).

The host part, which `recompiler_corpus/library` runs, translates the `objc` fixture with `XL_LIBRARY=1`, then checks
the dylib statically:

- the segments are in ascending address order, which dyld requires, and `__LINKEDIT` is after the guest segments;
- the dylib exports exactly `_xl_library_init` and `_xl_library_diagnostics`;
- the armv7 host app (`host.m` with `xl_loader.c`) builds and signs.

The device part copies the dylib and the host to the claimed phone and runs the host. The host first grows its own
resident set to the size given as an argument (85 MB by default, `XL_LIBRARY_RESIDENT_MB`), loads any dylibs named after
it the way an app's frameworks are loaded, reserves the range, loads the library, and prints `ok <name>` for 11 checks:
`reserve`, `load`, `class` (`NSClassFromString`), `create`, `methods`, `describe` (a string built in the library),
`bundle` (the library's `hostBundle` is the app's `mainBundle`), `bundle.path`, `token` (a value that depends on a
static of the library), `completion` and `completion.thread` (a block called on another thread). It prints
`measure <step> resident=… virtual=… threads=…` after each step and the address map of the process (`map <step>
<start>-<end> <protection>`). A watchdog `alarm` ends a hung host after 180 seconds.

`./xmakew l -P . recompiler/tests/library/check.lua <out> [objc|swift] [--host-only]` runs a variant whole. The `swift`
variant needs `XL_SWIFTOBJC_LIBS` (the same folder as swiftobjc) and takes the translation of the guest `libswiftCore`,
`libc++` and `libc++abi` with it, which is minutes to an hour of compile time depending on the load of the machine.

### cxxinit and refrepro

These build targets each translate an app to an `.app`, for a device or the emulator.

- `recompiler_cxxinit` covers C++ static initialisers in an Objective-C++ app.
- `recompiler_blockid` is a console program that passes Objective-C blocks across the guest boundary: a block stored in an `NSArray` and read back and invoked from the guest, its identity kept, a block used as a dictionary key, a block that survives the release of its array, and a block invoked from the host. It prints `PASS` or `FAIL`.
- `recompiler_refrepro` is built with ARC, like OneBusAway, so ivar stores compile to `objc_storeStrong`. That is the
  release-of-old-ivar site that faulted.

## perf: devtime

`recompiler_devtime` builds the on-device wall-clock benchmark, which compares translated and native code. It is a
normal armv7 iOS command-line executable that links libSystem and libm.

1. The arm64 kernels are lifted to armv7.
2. `kernel_addrs.h` is generated: each kernel's guest address is its `_k_<name>` symbol plus `0x10000000`, in
   `native_run.c`'s order.
3. The native kernels, the dispatch and the timing main are compiled.
4. Everything is linked with the guest segments fixed at their vmaddrs (`-no_pie` and the layout), and with libSystem
   for `mach_absolute_time`, `task_info`, `printf` and libm.
