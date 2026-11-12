# Library mode

What `XL_LIBRARY=1` builds, the loader API, and what was measured on the iPhone 4S (iOS 6.1.3) with a host of about
85 MB resident. [Why it is built this way](../../explanation/recompiler/library-mode.md); [the commands](../../guides/recompiler/build-and-translate.md#translate-a-library).

## Build interface

`XL_LIBRARY=1 ./xmakew l -P . recompiler/tools/translate.lua <input>.dylib includes.h out/ [guest images]` writes
`out/<name>.dylib`.

| Variable | Meaning | Default |
|---|---|---|
| `XL_LIBRARY` | build a dylib instead of an executable | unset |
| `XL_BASE` | address of the first guest segment | `0x10000000` |
| `XL_INSTALL_NAME` | install name of the output | `@rpath/<name>.dylib` |
| `XL_SWIFT_HOST_ANCESTORS` | Swift classes with an Objective-C ancestor are host objects with a twin | unset |
| `XL_REPLACES` | guest images that stand for system libraries | unset |

Layout of the output, from low to high addresses:

| Part | Address | Size |
|---|---|---|
| host `__TEXT`, `__DATA` | `XL_BASE` minus the window | lifted code + runtime |
| guest `__X<n>TEXT`, `__X<n>DATA`, one pair per image | from `XL_BASE`, at the addresses the guest was linked at | the guest's own |
| `__LINKEDIT` | after the last guest segment | symbols, signature |

The window is the size of the lifted bytes plus 8 MB, rounded up to 16 MB. Exports are exactly `_xl_library_init` and
`_xl_library_diagnostics`; the check fails on anything else.

## Loader API (`recompiler/include/xl_loader.h`)

| Function | Does |
|---|---|
| `xl_reserve(path)` | reads the header of the library, takes its range with `vm_allocate` at the fixed address, `VM_PROT_NONE` |
| `xl_load(path)` | gives the reservation back, `dlopen`s, calls `xl_library_init`, which checks the header against the link address |
| `xl_load_error()` | text of the last failure |

Statuses: `XL_LOAD_OK`, `XL_LOAD_BAD_IMAGE`, `XL_LOAD_RANGE_BUSY`, `XL_LOAD_DLOPEN_FAILED`, `XL_LOAD_RELOCATED`. A
library that dyld placed elsewhere is `XL_LOAD_RELOCATED` for good; the runtime does not run in it.

## What the phone's dyld does

Measured on iOS 6.1.3, armv7:

- `dlopen` places a dylib at its preferred address in a PIE and in a non-PIE process, if the range is free.
- A dylib linked into the executable at launch is slid in a PIE process.
- ld64 links an armv7 dylib with guest segments at `0x28000000` and `0x2a000000`; at `0x48000000` and above it refuses
  ("would make the output executable exceed available address range"), though a plain dylib links at `0x4f000000`.
- The 119 MB dylib prints `dyld: F_ADDFILESIGS failed ... errno=7` (its signature is 1.5 MB) and loads.
- Mapped code that is never run costs about no resident memory.

## The check

`./xmakew l -P . recompiler/tests/library/check.lua <out> [objc|swift] [--host-only]` builds a fixture library
(`RCFClient`, `RCFToken`; Objective-C or Swift) and a host app (`xl-library-host`), checks the layout of the output
(ascending segments, `__LINKEDIT` after the guest, two exports), and on the claimed phone grows the host to
`XL_LIBRARY_RESIDENT_MB` (85) and expects these names `ok`, then `done` and `exit=0`:

| Name | Proves |
|---|---|
| `reserve`, `load` | the range was taken, the library loaded at its link address |
| `class`, `create` | the public class is found by name and made |
| `methods`, `describe` | calls with `NSInteger` arguments and results, state kept between calls |
| `bundle`, `bundle.path` | the library sees the host's `NSBundle.mainBundle` (same object, same path) |
| `token` | an object result of a public method |
| `completion`, `completion.thread` | a host block called from the library, on a thread that is not the main one |

## Measurements

The host grows its heap with 1 MB `malloc` chunks until `task_info` reports 85 MB resident (87,3xx K counting the
frameworks). Sizes are K.

| Step | Objective-C variant | Swift variant (guest libswiftCore, libc++, libc++abi) |
|---|---|---|
| library file | small | 119.5 MB |
| host before | 87,328 resident, 360,064 virtual, 1 thread | 87,324, 360,064, 1 |
| after `xl_reserve` | 87,332, 377,568 | 87,332, 503,360 (+143 MB virtual) |
| after `xl_load` | 87,408 (+80) | 88,676 (+1.35 MB) |
| after the calls | 87,728 (+320) | 90,696 (+2.0 MB) |
| after the background call | 87,772, 394,280, 2 threads | 90,880, 521,108, 5 threads |

The Swift variant costs 2.2 MB of resident memory with the first calls done, though its file is 119 MB: only the pages
the run touches become resident. The five threads are the host's main thread and the workers that
`performSelector(inBackground:)` and Dispatch started.

Address map of the Swift variant at the default base: host `__TEXT` at `0x08000000` (`0x6894000`, 104 MiB), host
`__DATA` at `0x0e894000`, guest `__X0` to `__X4` from `0x10000000` to `0x10910000` (`__X1` is the guest libswiftCore:
text `0x4c4000` at `0x10100000`, data at `0x105c4000`), `__LINKEDIT` at `0x10910000` (`0x2e0000`). The ObjC variant
occupies `0x0f000000` to `0x10118000` (17 MB).

The host heap of a plain app fills the low addresses from about `0x185000` upwards, malloc arenas sit near
`0x1f500000` to `0x20800000`, the stack at `0x2fcc5000`, dyld at `0x2fe02000`, the shared cache from `0x31bcc000`.

### A host with Telegram's address space

Telegram 13 (armv7, iOS 6) is a PIE executable of 56 KB plus frameworks that add up to about 190 MB of images, loaded
first-fit from about `0x6000` to about `0xC000000`. The host was started with `0x01000000` to `0x0c800000` occupied (191
MB, `@LOW-HIGH` argument of `host.m`):

| Library | Result |
|---|---|
| default base | `FAIL reserve`: "another mapping holds 0x8000000-0x10bf0000, where lo.dylib must be loaded"; the host is not harmed |
| `XL_BASE=0x2a000000` | 11 of 11 `ok`, resident 88,724 K after load and 90,872 K at the end, virtual 681 to 709 MB, 4 threads |

A library therefore needs a base that the host's images and heap do not reach. `0x2a000000` is above Telegram's
images and below the stack; whether a particular app leaves it free is for the app to measure with `xl_reserve` at
launch, and a library whose reservation fails answers with a status, not a crash.

### A host that has its own Swift runtime

The Telegram13 frameworks include an armv7 `libswiftCore.dylib` (7.26 MB). Preloaded into the host
(`dlopen`, `RTLD_GLOBAL`) next to the library:

- the Objective-C runtime prints 31 duplicate-class warnings when the library loads ("Class `_TtCs12_SwiftObject` is
  implemented in both .../libswiftCore.dylib and ??. One of the two will be used. Which one is undefined."), among them
  `__SwiftValue`, `__SwiftNativeNSArrayBase`, `_TtCs19__EmptyArrayStorage`, `_TtCs15__StringStorage`: the Objective-C
  classes of the Swift runtime exist twice, the host's and the guest's;
- the shadow of a guest class whose name the host already has (the first one met was
  `_TtCs27_KeyedEncodingContainerBase`) could not be made ("a class of that name exists") and the run stopped. It is
  now registered under `<name>@<guest address>`, and the shadow table notes the alias.

With both in place the run is 11 of 11 `ok` on the phone: host 87,800 K resident, after `xl_load` 89,196 K, after the
calls 91,176 K, at the end 91,344 K, virtual 368,704 K before and 521,008 K at the end, 4 threads. The preloaded
runtime costs the host 0.5 MB more resident than the same host without it (87,324 K).

The warnings stay. A lookup by name (`NSClassFromString`, `objc_getClass`) of a class whose name both runtimes have
answers whichever one the Objective-C runtime holds, which can be the host's. Nothing in the fixture does that, and the
public classes of an SDK have their own names. A library that must not name-clash at all would need the translator to
prefix the names of the runtime's own classes; that is not done.

## Dead-strip and lazy loading

Not built; only measured and analysed.

- `xlate` lifts every function in `LC_FUNCTION_STARTS`, so the 119 MB of the Swift variant is almost all the lifted
  `libswiftCore`.
- The size on the phone is not in the resident set (see the table): pages that are never touched are never read.
  A strip would shrink the file, the install size and the address window (104 MiB of host `__TEXT` in the Swift variant),
  which matters for where the library can be placed (see the Telegram map).
- A strip by reachability from the public classes of the SDK is not trivial: Swift metadata refers to code and to other
  metadata by relative pointers, conformances are found by a runtime scan of a section, and protocol witness tables
  and the Objective-C runtime reach functions by selector. A safe reachability needs the word-by-word scan of data for
  relative references; an unsafe one fails at run time with a trap in a function that was stripped.
- Lazy loading (lifting a function when first called) needs the compiler on the phone and is not planned.

## Not done

- No library with the real reCAPTCHA SDK: the fixture stands for it. The SDK's own translation is block A and B.
- The host's UI and its own use of the library were not run: the fixture host is a console tool, `Telegram13` was not
  modified.
- The guest `libswiftCore` is not shared between two libraries.
