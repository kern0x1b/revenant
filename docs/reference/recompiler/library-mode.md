# Library mode

What `XL_LIBRARY=1` builds, the loader API, and what was measured on the iPhone 4S (iOS 6.1.3) with a host of about
85 MB resident. [Why it is built this way](../../explanation/recompiler/library-mode.md); [the commands](../../guides/recompiler/build-and-translate.md#translate-a-library).

## Build interface

`XL_LIBRARY=1 ./xmakew l -P . recompiler/tools/translate.lua <input>.dylib includes.h out/ [guest images]` writes
`out/<name>.dylib`.

| Variable | Meaning | Default |
|---|---|---|
| `XL_LIBRARY` | build a dylib instead of an executable | unset |
| `XL_BASE` | address of the first guest segment: where the loader maps the guest image | `0x10000000` |
| `XL_INSTALL_NAME` | install name of the output | `@rpath/<name>.dylib` |
| `XL_SWIFT_HOST_ANCESTORS` | Swift classes with an Objective-C ancestor are host objects with a twin | unset |
| `XL_REPLACES` | guest images that stand for system libraries | unset |
| `XL_NAMESPACE` | prefix of the Objective-C class names of every guest image but the first (the runtime and the overlays); `none` leaves the names as they are | `XLG.` |

The output is one dylib with two kinds of content:

| Part | Where | Holds |
|---|---|---|
| host `__TEXT`, `__DATA`, `__LINKEDIT` | wherever dyld puts the dylib (it is linked at address 0 and slid) | lifted code, runtime, the table of slots |
| `__XGUEST,__image` | a section in the file, read-only, aligned to 16 KiB; dyld maps it and nobody reads it there | the guest image: the guest's segments as bytes, to be mapped at the addresses the guest was linked at |

There are no guest segments in the link any more (`__X<n>TEXT`, `__X<n>DATA` are gone), and no window under `XL_BASE`: the
host part does not depend on where the guest is. Exports are exactly `_xl_library_init` and `_xl_library_diagnostics`;
the check fails on anything else.

### The guest image (`recompiler/include/xl_guest_image.h`)

The loader, the runtime and `xlate` include one header, which is the format. All numbers are little-endian 32-bit words,
every address, size and offset is a multiple of the 16 KiB granule (the guest is arm64, its segments are 16 KiB
aligned; `xlate` refuses a segment that is not).

| Part | Layout |
|---|---|
| header (at the start of the section) | `magic` `XLGI` (`0x49474c58`), `version` (1), `low`, `high` (the range of the guest, `high` is the end of the last segment), `segment_count` |
| `segment_count` records, right after the header | `address`, `size` (in the guest), `offset` (of its bytes from the start of the section), `length` (bytes in the file: the segment without its zero tail, up to the granule), `protection` (`1` read, `2` write; what the segment has when the library is ready) |
| bytes | each segment's `length` bytes at its `offset`; a segment that is all zeros has `length` 0 |

The slots are not in the section. `xl_guest_slots` (`{address, value}` words, sorted by address) and `xl_guest_slot_count`
are host data of the dylib, because the `value` of a slot is the address of a symbol (a class, an `xl_objc_ro_*` structure,
`__CFConstantStringClassReference`, a system symbol the guest binds to) that dyld relocates when it loads the dylib. A guest
word that holds such an address is zero in the bytes. In a segment of the guest the Objective-C classes and protocols are
ordinary bytes at their own addresses, and the generated code refers to them by number.

### Load order

1. `xl_reserve` reads the header of the file (not the section in memory): refuses a wrong `magic` or `version`, takes
   `[low, high)` with `vm_allocate` at the fixed address and `VM_PROT_NONE`, and takes the size of the host part
   (the sum of the dylib's own segments) anywhere with `VM_PROT_NONE`. If the guest range is held it fails with the
   region that holds it, its range, what it is (an image's path, `malloc`, `stack`, a memory tag) and its size.
2. `xl_load` gives the host reservation back and `dlopen`s the dylib: dyld takes the first hole that fits, which is the one just
   given back. It calls `xl_library_init`.
3. `xl_library_init` checks the header again (`magic`, `version`, that every segment is inside `[low, high)`, that every slot
   is inside it), checks that `[low, high)` is one untouched `VM_PROT_NONE` range (it writes nothing if it is not), then for
   each segment: `mmap(address, length, READ|WRITE, MAP_FIXED|MAP_PRIVATE)` of the file at the segment's `offset`, and
   `vm_protect` read-write for the zero tail. It writes every slot, applies the segment's `protection`, runs the guest's
   initializers (once, behind a lock) and returns.

Pages of the guest that nothing touches stay clean file pages: they are not in the resident set and the system can drop them.

## Loader API (`recompiler/include/xl_loader.h`)

| Function | Does |
|---|---|
| `xl_reserve(path)` | reads the guest image's header from the file and takes the guest range and room for the host part, `VM_PROT_NONE` (the load order above) |
| `xl_load(path)` | reserves if that was not done, gives the host room back, `dlopen`s, calls `xl_library_init`; the library owns the guest range from then on |
| `xl_load_error()` | text of the last failure |

Statuses: `XL_LOAD_OK`, `XL_LOAD_BAD_IMAGE` (not an armv7 dylib, no guest image, a `magic` or `version` that is not read: the message says which, and
the version found), `XL_LOAD_RANGE_BUSY` (the guest range is held: the message names the holder; or the reservation is
not an untouched inaccessible range when the library attaches; or no hole of the host's size), `XL_LOAD_DLOPEN_FAILED`,
`XL_LOAD_MAP_FAILED` (`mmap` or `vm_protect` of the guest's segments failed). A status after the library's initialization has run is final: later
calls return it, and the guest range is given back.

The library reports `XL_LIBRARY_OK`, `XL_LIBRARY_BAD_FORMAT`, `XL_LIBRARY_NOT_RESERVED` or `XL_LIBRARY_MAP_FAILED` from
`xl_library_init` (`xl_guest_image.h`); the loader turns them into the statuses above. Called before `xl_load`
by a host that never reserved, `xl_library_init` answers `XL_LIBRARY_NOT_RESERVED` and maps nothing, and any entry of the
library aborts with "the guest image of the translated library is not attached".

## What the phone's dyld and kernel do

Measured on iOS 6.1.3, armv7:

- `dlopen` of a dylib linked at address 0 slides it into the first hole that fits (`vm_allocate` anywhere): the range that
  `xl_reserve` took and `xl_load` gave back, in the same call.
- On the 4S, `MAP_FIXED|MAP_PRIVATE` of the pages of a file over a `VM_PROT_NONE` `vm_allocate` reservation works: the
  mapping replaces the reservation exactly (the rest of the reservation stays `VM_PROT_NONE`), the bytes are the file's, a
  write copies the page and does not change the file, `vm_protect` to read-only makes a write fault, `vm_protect` to
  read-write over the rest gives zero pages. The probe is 25 checks, all `ok` (small dylib with a `__XGUEST,__image` section at
  file offset `0x4000`).
- A 119 MB dylib prints `dyld: F_ADDFILESIGS failed ... errno=7` (its signature is 1.5 MB) and loads.
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

The `swift` variant builds the host with Swift code of its own (`hostswift.swift`, armv7, iOS 6.0) and its own
`libswiftCore`, and expects four names more. The host's Swift makes a struct boxed as `AnyObject`, an `[Any]` and a
`String`; `host.m` keeps the class of each and the class of every name in the host's `libswiftCore`:

| Name | Proves |
|---|---|
| `host.bridge.before` | before the library loads, the three are objects that are not of the namespace |
| `host.names` | after `xl_load`, every name of the host runtime answers with the host's class |
| `names.disjoint` | the library registered classes, and none has the name of a class of the host runtime |
| `host.bridge.after` | after the calls, the three are the same classes with the same contents, and the names still hold |

| Variable | Meaning |
|---|---|
| `XL_LIBRARY_HOST_RUNTIME` | folder on the phone with the host's runtime and overlays (Telegram13's `Frameworks`); unset: the package's armv7 `libswiftCore`, `libc++` and `libc++abi` are copied next to the host |
| `XL_LIBRARY_HOST_BRIDGING` | the host's Swift imports Foundation, so the `[Any]` and the `String` cross as `NSArray` and `NSString` and their contents are checked; needs a runtime folder with a Foundation overlay iOS 6 can load |
| `XL_LIBRARY_RESIDENT_MB` | resident size the host grows to before it loads the library (85) |

iOS 6.1.3 has no `@rpath` in dyld: a library named `@rpath/libswiftCore.dylib` is found through
`DYLD_FALLBACK_LIBRARY_PATH` by its leaf name, which is how the check starts the host. The package's
`libswiftFoundation` needs `NSDimension`, which iOS 6 lacks, and Telegram's patched overlay does not, hence the two
runtime sources. Without the Foundation overlay Swift boxes an array and a string as `__SwiftValue`, and the check
compares the classes only.

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

The table is the first measurement, with a 119.5 MB library and a host without Swift. The Swift variant has grown to
162 MB since; its window is 176 MiB (host `__TEXT` at `0x21000000` for the base below), so the host that has a Swift
runtime needs `XL_BASE=0x2c000000` (next section), and the numbers with a Swift runtime of its own are in
[the namespace section](#a-host-that-has-its-own-swift-runtime).

Address map of the first Swift variant at the default base: host `__TEXT` at `0x08000000` (`0x6894000`, 104 MiB), host
`__DATA` at `0x0e894000`, guest `__X0` to `__X4` from `0x10000000` to `0x10910000` (`__X1` is the guest libswiftCore:
text `0x4c4000` at `0x10100000`, data at `0x105c4000`), `__LINKEDIT` at `0x10910000` (`0x2e0000`). The ObjC variant
occupies `0x0f000000` to `0x10118000` (17 MB).

Where the heap, the stack and the images of an app sit, and why, is in [the next section](#the-address-space-of-a-host-on-the-4s).

### The address space of a host on the 4S

iOS 6.1.3, armv7, measured with a probe injected through `DYLD_INSERT_LIBRARIES` into 20 launches of Telegram13 (pass68, 282
images, no taps) and with a console tool that prints where its first `malloc` landed, 400 launches. The probe lists every
region (`vm_region_recurse_64`: range, protection, `user_tag`) when its constructor runs, which is the first code of the
process after libSystem, and again when the library's reservation is asked for; it also logs every `mmap` and `vm_allocate`
that lands between `0x10000000` and `0x30000000` with the frames of its caller.

| Zone | Where | Notes |
|---|---|---|
| images and first-fit mappings | `0x00078000` up to `0x10ebe000`-`0x110bd000` | Telegram13's executable and frameworks (271 MB). The executable slides by up to 1 MB; the frontier moved by 2 MB between the 20 launches. Every `mmap` that is not a malloc region (images, `fd=-1` anonymous mappings of 128 KB and less, file maps) takes the lowest hole that fits |
| free | up to `0x1c500000` | 180 MB at the frontier above |
| malloc heap | one run of tiny (`user_tag` 7, 1 MB) and small (tag 2, 8 MB) regions from a random start | the start is `0x1c500000 + k * 8 MB`, `k` 0 to 7, each value in about one launch of eight: 53, 43, 52, 41, 50, 57, 55 and 48 of 399 console launches, and 4, 1, 1, 4, 2, 4, 1, 3 of the 20 of Telegram13. The regions follow each other upwards from there: the allocator asks for the address after its last region and the kernel gives the next free hole at or above it. In 1 launch of 400 the heap was in the lowest hole (`0x00100000`) instead |
| heap size | 19 MB before the first initializer, 21 to 22 MB when `xl_reserve` runs | dyld's own allocations while it maps the images account for the 19 MB; the initializers of the frameworks add 2 to 3 MB |
| free | from the top of the heap (at most `0x21300000` at `xl_reserve`) to the stack | 233 MB at that heap top |
| stack | top `0x2fe00000`, bottom `0x2fc02000` or higher | the main thread's 1 MB stack plus a random pad of up to 2 MB |
| dyld, shared cache | `0x2fe00000` and above | the shared region `0x30000000` to `0x40000000` is the kernel's |

When an allocation lands on a reserved range the allocator goes on above it (a 16 MB small region took `0x2ccd4000` when
`0x21000000` to `0x2ccd4000` was reserved), and once its hint is used up the new regions go to the lowest holes, which is
how a process with a 193 MB reservation runs on.

What this means for a range that must be at a fixed address:

- No constructor is early enough to be ahead of the heap: the first initializer already finds 19 MB of it, and the 2 to 3 MB
  between that and `xl_reserve` are of no consequence. The heap's start is the random part, and it is a part of the
  platform, not of the app: a console tool on the same phone has the same eight starts.
- A range that overlaps `0x1c500000` to `0x21300000` fails in one launch of eight (the start `0x1fd00000` plus 22 MB passes
  `0x21000000`: the three refusals of the 20 launches were all that start). The range `0x21000000` to `0x2ccd4000` of the
  162 MB Swift library is 198 MB, and the room that is free in every launch is 180 MB below the heap and 233 MB between the
  heap and the stack, before the margins of either side: it does not fit in either.
- A range below `0x1c500000` is clear of the heap in every launch, and clear of the images by `0x1c500000` minus their frontier.

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

The 162 MB Swift library (window 176 MiB) does not fit there any more: below `0x2a000000` its host code meets the
heap that a host with its own Swift runtime has before `main` (`0x1e500000` to `0x1f900000`), and `xl_reserve` answers
"another mapping holds ...". `XL_BASE=0x2c000000` works (host `__TEXT` `0x21000000`, guest segments to about
`0x2c910000`, `__LINKEDIT` after them); ld64 refuses guest segments at `0x48000000` and above. `host.m` calls
`xl_reserve` before it grows its heap, as an app does from a constructor.

### A host that has its own Swift runtime

The Telegram13 frameworks include an armv7 `libswiftCore.dylib` (7.26 MB) and a patched Foundation overlay. A host with a
Swift runtime and Swift code of its own has classes of the same names as the guest runtime (`__SwiftValue`,
`_TtCs12_SwiftObject`, `__SwiftNativeNSArrayBase`, the array and string storage classes). Without a namespace the
Objective-C runtime printed 31 "Class X is implemented in both .../libswiftCore.dylib and ??. One of the two will be used.
Which one is undefined." warnings when the library loaded, kept either class of a pair, and the shadow of a guest class
whose name the host had (the first one met was `_TtCs27_KeyedEncodingContainerBase`) could not be made.

`XL_NAMESPACE` (default `XLG.`, [why](../../explanation/recompiler/library-mode.md)) registers the guest runtime and the
overlays under the prefix, so the host keeps its names and a clash is the exception:

- the translator writes `XLG.<name>` into the class of every guest image but the first, and three tables into the
  generated code: `xl_namespace_prefix`, `xl_namespaced_classes` (the namespaced Swift classes by guest address),
  `xl_namespace_modules` (the modules whose classes the runtime may make later);
- `xl_build_shadow` registers the shadow of a moved Swift class under the prefix when the class is in the first table
  or its mangled name is in a namespaced module (a generic instantiation the guest runtime made); a class that still
  clashes is registered under `<name>@<guest address>`;
- `objc_getClass`, `objc_lookUpClass` and `class_getName` are manual bridges: a name is looked up under the prefix
  first, a name of a namespaced module only there, and the name the guest gets back has no prefix. They are bridged in an
  executable too; with no prefix they pass the call through.

Measured on the 4S with `XL_BASE=0x2c000000`, Swift variant: 15 of 15 `ok` (the 11 of the check and the 4 of the Swift
host), no "implemented in both" line.

| Host | Resident K: host, loaded, called, end | Virtual | Threads |
|---|---|---|---|
| Telegram13's `libswiftCore` and Foundation overlay, bridging on (`XL_LIBRARY_HOST_BRIDGING`) | 88,000, 90,600, 92,420, 92,504 | about 575 MB | 5 |
| the package's armv7 runtime next to the host | 87,912, 89,984, 92,040, 92,224 | | 4 |

The host's Swift is the same before and after the library loads: 42 classes of its runtime answer by name with the same
objects, the library registers 33 classes and none has a name of the host runtime, and the box, the `[Any]` and the
`String` that the host's Swift makes are the same classes with the same contents. The Objective-C variant is 11 of 11.

Not covered: protocols are not namespaced (`objc_getProtocol` is not bridged); `NSClassFromString` and
`NSStringFromClass` are not bridged, so a guest that goes through them meets the prefixed names; the secondary guest
images of an SDK (not the runtime) are namespaced like the runtime, so a host reaches by name only the classes of the
first image.

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
- Not run on the phone after the namespace: the `swiftobjc` fixture (the three name bridges now apply to executables
  too, with a pass-through when there is no prefix) and a control with `XL_NAMESPACE=none` that shows the duplicate
  warnings come back.
