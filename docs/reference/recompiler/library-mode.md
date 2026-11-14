# Library mode

What `XL_LIBRARY=1` builds, the loader API, and what was measured on the iPhone 4S (iOS 6.1.3) with a host of about
85 MB resident. [Why it is built this way](../../explanation/recompiler/library-mode.md); [the commands](../../guides/recompiler/build-and-translate.md#translate-a-library).

## Build interface

`XL_LIBRARY=1 ./xmakew l -P . recompiler/tools/translate.lua <input>.dylib includes.h out/ [guest images]` writes
`out/<name>.dylib` and `out/<name>-classes.dylib`; the two files go into one folder, and the second is found by its name.

| Variable | Meaning | Default |
|---|---|---|
| `XL_LIBRARY` | build a dylib instead of an executable | unset |
| `XL_BASE` | address of the first guest segment: where the loader maps the guest image | `0x10000000` |
| `XL_INSTALL_NAME` | install name of the output | `@rpath/<name>.dylib` |
| `XL_SWIFT_HOST_ANCESTORS` | Swift classes with an Objective-C ancestor are host objects with a twin | unset |
| `XL_REPLACES` | guest images that stand for system libraries | unset |
| `XL_NAMESPACE` | prefix of the Objective-C class names of every guest image but the first (the runtime and the overlays); `none` leaves the names as they are | `XLG.` |

The output is two dylibs. The first, `<name>.dylib`, has two kinds of content:

| Part | Where | Holds |
|---|---|---|
| host `__TEXT`, `__DATA`, `__LINKEDIT` | wherever dyld puts the dylib (it is linked at address 0 and slid) | lifted code, runtime, the table of slots |
| `__XGUEST,__image` | a section in the file, read-only, aligned to 16 KiB; dyld maps it and nobody reads it there | the guest image: the guest's segments as bytes, to be mapped at the addresses the guest was linked at |

There are no guest segments in the link any more (`__X<n>TEXT`, `__X<n>DATA` are gone), and no window under `XL_BASE`: the
host part does not depend on where the guest is. Exports are `_xl_library_init`, `_xl_library_diagnostics` and one
`_xl_objc_category_<n>` for each Objective-C category of the guest (the registry refers to them); the check fails on
anything else.

The second, `<name>-classes.dylib`, is the registry: the lists that libobjc reads when it loads an image, and nothing
else. It has `__DATA,__objc_classlist` (the guest's classes, by their guest address), `__objc_protolist` (its
protocols, by address), `__objc_catlist` (the categories, which are the first dylib's `xl_objc_category_<n>` structures,
bound by dyld) and `__objc_imageinfo`; no code, no exports, a dependency on the first dylib by its install name. It
is separate because libobjc registers the classes of an image while `dlopen` loads it, and reads the class
structures then: they are in the guest image, which the library maps only after dyld has placed the first dylib and
relocated the slots that point into it. The first dylib has none of these lists. The registry is loaded after the
guest image is in place and before the guest's initializers run.

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
   It also refuses a library whose registry file (`<name>-classes.dylib` in the same folder) is not there.
2. `xl_load` gives the host reservation back and `dlopen`s the dylib: dyld takes the first hole that fits, which is the one just
   given back. It calls `xl_library_init`.
3. `xl_library_init` checks the header again (`magic`, `version`, that every segment is inside `[low, high)`, that every slot
   is inside it), checks that `[low, high)` is one untouched `VM_PROT_NONE` range (it writes nothing if it is not), then for
   each segment: `mmap(address, length, READ|WRITE, MAP_FIXED|MAP_PRIVATE)` of the file at the segment's `offset`, and
   `vm_protect` read-write for the zero tail. It writes every slot, applies the segment's `protection`, `dlopen`s the
   registry (libobjc registers the guest's classes, protocols and categories), runs the guest's initializers (once, behind a
   lock) and returns.

Pages of the guest that nothing touches stay clean file pages: they are not in the resident set and the system can drop them.

## Loader API (`recompiler/include/xl_loader.h`)

| Function | Does |
|---|---|
| `xl_reserve(path)` | reads the guest image's header from the file and takes the guest range and room for the host part, `VM_PROT_NONE` (the load order above) |
| `xl_load(path)` | reserves if that was not done, gives the host room back, `dlopen`s, calls `xl_library_init`; the library owns the guest range from then on |
| `xl_load_error()` | text of the last failure |

Statuses: `XL_LOAD_OK`, `XL_LOAD_BAD_IMAGE` (not an armv7 dylib, no guest image, a `magic` or `version` that is not read: the message says which, and
the version found; no registry next to the library), `XL_LOAD_RANGE_BUSY` (the guest range is held: the message names the holder; or the reservation is
not an untouched inaccessible range when the library attaches; or no hole of the host's size), `XL_LOAD_DLOPEN_FAILED` (the library or its registry; the message has dyld's text),
`XL_LOAD_MAP_FAILED` (`mmap` or `vm_protect` of the guest's segments failed). A status after the library's initialization has run is final: later
calls return it, and the guest range is given back.

The library reports `XL_LIBRARY_OK`, `XL_LIBRARY_BAD_FORMAT`, `XL_LIBRARY_NOT_RESERVED` or `XL_LIBRARY_MAP_FAILED` from
`xl_library_init` (`xl_guest_image.h`); the loader turns them into the statuses above. Called before `xl_load`
by a host that never reserved, `xl_library_init` answers `XL_LIBRARY_NOT_RESERVED` and maps nothing, and any entry of the
library aborts with "the guest image of the translated library is not attached".

### The address-space map (`XL_LOADER_MAP`)

With `XL_LOADER_MAP` set in the environment to anything but `0`, the loader prints the process's virtual memory to
`stderr` (the runtime's crash handler to the crash log or `stderr`, where its other lines go) in the phases
`before-reserve` (before `xl_reserve` takes anything), `reserve` (after it), `load` (after `xl_load`; a failed call prints
`reserve-failed` or `load-failed`), and, once `xl_library_diagnostics` has installed the handlers, `crash` (a fatal
signal) and `fault` (a guest fault). With the variable unset nothing is printed and no region is read. One line per
fact, fields separated by single spaces, addresses and sizes in hex:

| Line | Fields |
|---|---|
| `xl-map PHASE begin`, `xl-map PHASE end` | the walk of one phase |
| `xl-map PHASE region START END SIZE PROT/MAX SHARE TAG NAME` | one mapping from `vm_region_recurse_64` (submaps are entered): `PROT` and `MAX` as `rwx` with `-` for a missing bit, `SHARE` the share mode (`cow`, `private`, `empty`, `shared`, `true_shared`, `private_aliased`, `shared_aliased`), `TAG` the `user_tag` in decimal, `NAME` the path of the image whose segment overlaps it, else `malloc`, `malloc small`, `malloc large`, `malloc tiny` or `stack`, else `-` |
| `xl-map PHASE hole START END SIZE` | a free range of 1 MB or more between two mappings, counted up to `0x40000000` (`XL_VM_MAP_USER_END`), where a 4S process's address space ends; a range above that is not free, it is not there |
| `xl-map PHASE summary mapped=… free=… largest_start=… largest_size=… free_below_0x30000000=…` | totals over the walk (the holes of every size count in `free`) |

Besides the phases above the loader prints `before-dlopen` (after `xl_load` gave the host's room back, right before `dlopen`:
its `largest_size` is the hole dyld has to choose from) and, after `reserve`, one line
`xl-map reserve config host_reserve=0|1 host_size=… host_low=… guest_low=… guest_high=…`.

The code is one header, `include/xl_vm_map.h`, that the loader and the runtime both include.

### `XL_LOG` (the runtime's files on the phone)

A translated process writes nothing under `/private/var/revenant` by default. `XL_LOG` in the environment, or the file
`/private/var/revenant/xl-log` (for an application that SpringBoard launches, which has no environment of its own),
turns on the files that every process used to append to: `xlate-crash.log` (the crash handler and `xl_fault`),
`xl-exit.log` (each exit and each terminating signal, with the guest frames), `xlate-exception.log` (an uncaught
exception), `xl-missing.log` (a selector the null object answered), `xlate-variant-miss.log` and `xlate-nobridge.log`.
A file bigger than 1 MiB is emptied when the next process opens it, so none of them grows without bound. With
the switch off the crash handler prints to stderr, which is where the test below reads it. The files that had a switch
of their own (`xl-trace`, `xl-collect`, `xl-shadow-log`, `xl-trace-errno`, `xl-memlog`, `xl-exp-guide-superview`,
`xl-stubs.txt`, `XL_INIT_TRACE`) still need it and are not limited by `XL_LOG`. The library test crashes the host with the
switch (the crash handler's file has the `xlate: signal 6` lines) and without it (the lines are on stderr and the file
is not created).

### `XL_LOADER_HOST_RESERVE=0` (diagnostics)

A diagnostic switch for comparing placements, not a mode to ship: with `XL_LOADER_HOST_RESERVE=0` in the environment
`xl_reserve` takes only the guest range (at its fixed address) and leaves the room for the host part to `dlopen` at
`xl_load`, which then takes the first hole that fits when it runs. Unset, or any other value, nothing changes. The
risk of the switch is a `dlopen` that finds no hole of the host part's size when `xl_load` runs late in the process's life
(`XL_LOAD_DLOPEN_FAILED`, with dyld's text); `before-dlopen` and its `largest_size` against `host_size` of the config line
measure whether one is there. The library test runs the host with the switch and `XL_LOADER_MAP=1` and expects the same
`ok` names, a config line with `host_reserve=0` and `host_low=0x0`, no inaccessible region of the host part's size after
`xl_reserve`, the guest range still held, and the library's image after `xl_load`.

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
- A library whose install name is `@executable_path/<leaf>` is found by dyld with no environment: the registry, which depends
  on the library by that name, loads when the host is started without `DYLD_FALLBACK_LIBRARY_PATH` (12 checks in each of 10
  launches and the 4 controls, `XL_LIBRARY_INSTALL_NAME=executable` of the check). A name `@rpath/<leaf>` is found only through
  that variable.

## The check

`./xmakew l -P . <absolute path of>/recompiler/tests/library/check.lua <out> [objc|swift] [--host-only]` builds a fixture
library (`RCFClient`, `RCFToken`, and a category `RCFClient (RCFExtra)`; Objective-C or Swift) and a host app
(`xl-library-host`). The path of the script has to be absolute (the include list it writes holds paths relative to it
otherwise). The fixture is linked with `-no_objc_category_merging`: ld64 merges a category into its class when both are in
one dylib, which leaves the category list empty and the check of the registry with nothing to prove.

The host part of the check is the layout of the output (no `__X<n>` segment, `__LINKEDIT` and `__XGUEST` present, the header
(`magic`, `version`, a range that is granule-aligned and not below `XL_BASE`), exports that are the two entry points and the
`_xl_objc_category_<n>` names and nothing else, a registry with only the `__objc_*` sections, no code and no exports). On the
claimed phone the check copies the library and its registry into one folder, runs four negative controls, then grows the
host to `XL_LIBRARY_RESIDENT_MB` (85) `XL_LIBRARY_LAUNCHES` times (1) and expects these names `ok`, then `done` and `exit=0`
in every launch:

| Control | Host argument | Proves |
|---|---|---|
| a range another mapping holds | `@LOW-HIGH` over the guest range, `--expect=busy` | `xl_reserve` refuses, the message names the holder, the occupant's pages are untouched (`occupant.intact`), the class is not registered |
| a guest image format this loader does not read | a copy of the library whose `version` word is 2, `--expect=image` | `xl_reserve` refuses with the version found, nothing is registered |
| a library whose registry is not next to it | the library alone in a folder, `--expect=registry` | `xl_reserve` refuses and names the missing file, no crash |
| an init without a reservation, over a mapping with data | `+LOW-HIGH` (a read-write mapping with a sentinel), `--expect=direct` | `dlopen` of the library and the call of `xl_library_init` without `xl_reserve` is refused, and the occupant's data is intact |

After the launches the check runs the host with `XL_LOADER_MAP=1` and reads the map: the phases `before-reserve`, `reserve`,
`before-dlopen` and `load` each have `begin`, `end`, a `summary`, at least ten regions in ascending order and a hole of 1 MB or more
(at `before-dlopen` one of the host part's size, and the config line names that size);
the guest range has no mapping before `xl_reserve`, is covered by `---` regions after it, together with one `---` region
of the host part's size outside it, and has a readable segment after `xl_load`, which is also the first map that names
the library's own image. Then the host aborts after `xl_library_diagnostics` (`--abort`): with the variable set the crash
handler's output has the `crash` map and the guest range is readable in it; with it unset the handler prints its
`xlate: signal 6` lines and no `xl-map` line, and so do the launches above.

| Name | Proves |
|---|---|
| `reserve`, `load` | the guest range was taken at the guest's own addresses, the library loaded wherever dyld put it |
| `class`, `create` | the public class is found by name and made |
| `methods`, `describe` | calls with `NSInteger` arguments and results, state kept between calls |
| `bundle`, `bundle.path` | the library sees the host's `NSBundle.mainBundle` (same object, same path) |
| `token` | an object result of a public method |
| `category` | a method that a category of the guest adds to a guest class is found (the category is in the registry) |
| `completion`, `completion.thread` | a host block called from the library, on a thread that is not the main one |

The `swift` variant builds the host with Swift code of its own (`hostswift.swift`, armv7, iOS 6.0) and its own
`libswiftCore`, and expects four names more. The host's Swift makes a struct boxed as `AnyObject`, an `[Any]` and a
`String`; `host.m` keeps the class of each and the class of every name in the host's `libswiftCore`:

| Name | Proves |
|---|---|
| `host.bridge.before` | before the library loads, the three are objects that are not of the namespace |
| `host.names` | after `xl_load`, every name of the host runtime answers with the host's class |
| `names.disjoint` | the registry registered classes (the host takes the classes of the library's image and of its registry), and none has the name of a class of the host runtime |
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

The host grows its heap with 1 MB `malloc` chunks until `task_info` reports 85 MB resident (87 MB counting the frameworks).
`host.m` calls `xl_reserve` first, as an app does from a constructor, so the first row already holds the reservation (the guest
range and the room for the host part). Sizes are K; each cell is the lowest and the highest of 40 launches on the 4S
(iOS 6.1.3), the check of the same commit, `XL_BASE` `0x10000000`.

| Step | Objective-C variant (library 312 KB) | Swift variant (library 162.1 MB, guest libswiftCore, libc++, libc++abi) |
|---|---|---|
| host with the reservation, resident / virtual | 87,340-87,360 / 361,680 | 87,912-87,932 / 536,496 |
| after `xl_reserve` returned | 87,340-87,360 / 361,680 | 88,316-88,344 / 536,496 |
| after `xl_load` | 87,448-87,464 / 378,120 | 90,156-90,176 / 552,944 |
| after the calls | 87,752-87,772 / 378,120 | 92,148-92,172 / 552,944 |
| after the background call | 87,804-87,852 / 395,544-404,760, 2 threads | 92,300-92,368 / 563,276-580,708, 3 to 5 threads |

The Swift variant costs 4.4 MB of resident memory with the first calls done, though its file is 162 MB: only the pages
the run touches become resident, and mapped pages that are never run cost nothing. The threads are the host's main
thread and the workers that `performSelector(inBackground:)` and Dispatch started.

The address map of the Swift variant: the guest image `0x10000000` to `0x10910000` (10 segments, 9.1 MB: the guest
libswiftCore's text is `0x4c4000` at `0x10100000`, its data at `0x105c4000`; 6,438,912 bytes of it are in the library, the zero tails
are not), and a host part that dyld places in a hole of 162 MB (`__TEXT` 104 MiB). Before this layout the host part was
fixed too, at `0x21000000` to `0x2ccd4000` with the guest after it, which is what failed in 3 of 20 launches of Telegram13.

In the 40 launches of the Swift variant the start of the malloc heap was `0x1c500000` 8 times, `0x1cd00000` 7, `0x1d500000` 3,
`0x1e500000` 8, `0x1ed00000` 5, `0x1f500000` 6 and `0x1fd00000` 3 times (and in the 40 of the Objective-C variant at
85 MB all eight starts, `0x1fd00000` 5 times; in the 40 at 22 MB all eight, 6 times): the library loaded in every one. With the
ten launches of the first full check, 130 launches of the host were made without a refusal of the reservation, and
the controls (a held range, a format this loader does not read, a registry that is missing, an init without a
reservation) refused as they must, in every run.

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
| end of the address space | `0x40000000` | the process's user addresses end here, 1 GB in all: its own `0x00001000` to `0x30000000` (768 MB) and the kernel's shared region of 256 MB above it (the dyld cache, about 239 MB, and its submap), which the app cannot map into or allocate in. Measured on the 4S by the Telegram13 session (`vm_region` and `vm_allocate` probes): there is no free space above the cache |

When an allocation lands on a reserved range the allocator goes on above it, and once its hint is used up the new
regions go to the lowest holes, which is how a process with a large reservation runs on.

What this means for a range that must be at a fixed address:

- No constructor is early enough to be ahead of the heap: the first initializer already finds 19 MB of it, and the 2 to 3 MB
  between that and `xl_reserve` are of no consequence. The heap's start is the random part, and it is a part of the
  platform, not of the app: a console tool on the same phone has the same eight starts.
- A fixed range that overlaps `0x1c500000` to `0x21300000` fails in one launch of eight. The first design of library mode
  was one such range: the host code and the guest together, 198 MB from `0x21000000` for the 162 MB Swift library. It
  failed 3 of 20 launches of Telegram13 (all of the start `0x1fd00000`), and it fits neither of the free zones (180 MB
  below the heap, 233 MB between the heap and the stack) once the margins of both sides are taken.
- A range below `0x1c500000` is clear of the heap in every launch, and clear of the images by `0x1c500000` minus their frontier.

So the library has two parts that are placed differently. Only the guest image has to be at fixed addresses, because the
guest's pointers are absolute: it is 9.1 MB for the Swift library (`0x10000000` to `0x10910000`). The host part, which is
all the rest of the 162 MB, is linked at address 0 and dyld puts it in whatever hole is large enough (104 MiB of `__TEXT` in
the Swift variant): there are about 410 MB of holes in the two free zones, and it does not matter which one is taken.

### Choosing `XL_BASE`

The guest range `[XL_BASE, XL_BASE + guest size)` has to be inside the part of the first free zone that no launch of the
host app touches:

```
frontier + 64 MiB  <=  XL_BASE  and  XL_BASE + guest size  <=  0x1c500000 - 16 MiB
```

where `frontier` is the highest end of an image of the host app (the measured maximum for Telegram13 is `0x110bd000`, from
20 launches; it moves by about 2 MB between launches, and a changed set of frameworks moves it more). For Telegram13 that
is `[0x150bd000, 0x1b500000)`, 100 MB, and `XL_BASE=0x18000000` leaves 53 MiB for the guest above the base (the Swift
library's guest is 9.1 MB) and 47 MiB below it. The default `0x10000000` is in the middle of Telegram13's images and is
for a host that is not Telegram13. The rule is for the person who builds the drop; whatever the base, a host whose images
or heap hold the range gets `XL_LOAD_RANGE_BUSY` from `xl_reserve` with the name of the holder, never a crash.
The check (`recompiler/tests/library/host.m`) calls `xl_reserve` before it grows its heap, as an app does from a
constructor.

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

Measured on the 4S, Swift variant, 40 launches: 15 of 15 `ok` in each (the 11 of the check and the 4 of the Swift
host), no "implemented in both" line. The rows below were measured on the first design (a fixed range at
`XL_BASE=0x2c000000`) and were not repeated with the host's Swift runtime from Telegram13 on the new layout; the second
row is the new layout with the package's runtime (the table above has its counts).

| Host | Resident K: host, loaded, called, end | Virtual | Threads |
|---|---|---|---|
| Telegram13's `libswiftCore` and Foundation overlay, bridging on (`XL_LIBRARY_HOST_BRIDGING`) | 88,000, 90,600, 92,420, 92,504 | about 575 MB | 5 |
| the package's armv7 runtime next to the host (new layout, 40 launches) | 87,912-87,932, 90,156-90,176, 92,148-92,172, 92,300-92,368 | 563 to 581 MB | 3 to 5 |

The host's Swift is the same before and after the library loads: 42 classes of its runtime answer by name with the same
objects, the library registers 33 classes (31 through its registry, 2 that the library itself makes) and none has a name of the host runtime, and the box, the `[Any]` and the
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

## Known limitation: C++ exceptions from guest code

Objective-C exceptions work in a library as they do in an executable: `@throw` in a guest frame, an `NSException` the host
raises, `@catch` of a guest subclass, of `NSException` and of `id`, `@finally`, and C++ destructors and `catch (...)` on
the way (`recompiler/tests/libexceptions`, green on the 4S). A C++ exception that guest code throws does not work:

- `throw` ends in `__cxa_throw`, and guest libc++abi's `__cxa_throw` calls `_Unwind_RaiseException`; the call is a loud
  fault, `xlate: unsupported: _Unwind_RaiseException: a C++ exception thrown by translated code is not implemented`, and
  the process stops there. It was seen on the 4S on 2026-11-13 with a fixture of three translated guest functions: `throw 42`
  caught by `catch (...)` in the same function, a `std::runtime_error` thrown three frames down through destructors, and
  `std::vector::at` out of range. The guest `__cxa_exception` has the arm64 layout, which the host's personality routine
  cannot read, so the call cannot simply be handed to the host's `_Unwind_SjLj_RaiseException`.
- A typed `catch` of a class that a guest image defines (`catch (const std::out_of_range &)` with libc++ as a guest image)
  leaves a reference to the class's `typeinfo` symbol in the landing pad, which the link of the library does not resolve
  (`typeinfo for std::out_of_range` undefined; the link has `-U` only for the `__cxa_*` helpers). `catch (...)` links.
- Whether the reCAPTCHA SDK reaches such a `throw` was not shown. Its images carry libc++ (`std::vector::at`, `std::string`
  and others throw on error paths), so a C++ exception on an error path of the SDK would stop the process with the fault
  above, and a path of the SDK that needs the exception to be caught cannot work. It is a task for the exceptions block
  (block C), which owns the SjLj frames.

## Not done

- No library with the real reCAPTCHA SDK: the fixture stands for it. The SDK's own translation is block A and B.
- The host's UI and its own use of the library were not run: the fixture host is a console tool, `Telegram13` was not
  modified.
- The guest `libswiftCore` is not shared between two libraries.
- Not run on the phone: a control with `XL_NAMESPACE=none` that shows the duplicate warnings come back; the Swift host with
  the Telegram13 runtime and Foundation overlay (`XL_LIBRARY_HOST_RUNTIME`, `XL_LIBRARY_HOST_BRIDGING`) on the new layout; a
  category written in Swift (the Swift fixture has none, so the registry's category list is run by the Objective-C fixture only).
- Telegram13 itself: the range rule above comes from 20 launches of it with a probe and from the fixture's 130 launches with
  the heap of the host at its random starts; the 40 launches of the app with the library in its ipa wait for that ipa.
