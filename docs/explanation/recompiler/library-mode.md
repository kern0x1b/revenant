# Library mode

An app that links a translated library cannot start a second process for it: the reCAPTCHA token is bound to the app
(main bundle, bundle id, keychain, `Info.plist`). Library mode therefore builds the translated program as an armv7
dylib that an app loads into its own process, next to its own code and heap.

`XL_LIBRARY=1 ./xmakew l -P . recompiler/tools/translate.lua <input>.dylib includes.h out/ [guest images]` makes
`out/<name>.dylib` instead of an executable. [The reference](../../reference/recompiler/library-mode.md) has the
measurements; [the guide](../../guides/recompiler/build-and-translate.md#translate-a-library) has the commands.

## The constraint: a guest address is a host address

The guest keeps its arm64 memory image at its own addresses, and the lifted code reaches it by absolute address, so a
guest segment has to sit where it was linked. An executable gets that from `-segaddr` and `-no_pie`. A library has no
such thing: dyld slides a dylib to wherever it has room, and a library that asks for a fixed address gets it only while
nobody else took it.

The first version of library mode asked anyway: one fixed range for the lifted code and the guest together (198 MB for
the 162 MB Swift library). On the iPhone 4S the heap of an app starts at one of eight random places, and in one launch of
eight it sat in that range: 3 refusals in 20 launches of Telegram13. Nothing in the library can prevent that, and a retry
only hides it. So only what has to be fixed is fixed, and the library is two parts:

| Part | Address |
|---|---|
| the lifted code, the runtime, the bridges | the host part, linked at address 0 and placed by dyld in any hole that is large enough (104 MiB of `__TEXT` for the Swift library) |
| the guest image: its segments at the guest's own addresses | a range of 9.1 MB for the Swift library, at `XL_BASE` |

The guest image is not linked. It is a section of the dylib, `__XGUEST,__image`, that holds the bytes of the guest's
segments in a documented format ([the reference](../../reference/recompiler/library-mode.md#the-guest-image-recompilerincludexl_guest_imageh)),
and the loader maps it at the guest's addresses with `mmap(MAP_FIXED|MAP_PRIVATE)` over a reservation it took before.
A word of the guest that holds the address of something in the host (a class, a symbol of the system) is not in the
bytes: it is an entry of a table of slots that dyld relocates with the rest of the dylib's data, and the loader writes
it after the mapping.

The range that must be fixed is small, so it can be put where no launch of the host app has anything: above the app's
images and below the start of the random heap ([the map of the 4S](../../reference/recompiler/library-mode.md#the-address-space-of-a-host-on-the-4s),
[the rule for `XL_BASE`](../../reference/recompiler/library-mode.md#choosing-xl_base)). What the host part needs is only a hole of its
size, and the two free zones of the 4S (180 MB below the heap, 233 MB above it) together have about 410 MB of them.

## Loading

What the phone's dyld (iOS 6.1.3) does with a preferred address was measured, not assumed: a dylib that is `dlopen`ed at
run time is placed at its preferred address if the range is free, and a dylib linked at address 0 is slid into the first
hole that fits (dyld takes it with `vm_allocate` anywhere). The loader (`recompiler/src/loader/xl_loader.c`,
`include/xl_loader.h`, and the format header `include/xl_guest_image.h`) is a `dlopen` loader, linked into the host app:

1. `xl_reserve(path)` reads the guest image's header from the file, takes the guest range with `vm_allocate` at the fixed
   address, protected `VM_PROT_NONE`, and takes room for the host part anywhere, also `VM_PROT_NONE`. An app calls it as
   early as it can: the heap, other images and threads fill an address space from the bottom, and a range that is free at
   launch is not free at login. If the guest range is held it fails with a message that names the holder (an image's
   path, `malloc`, `stack`, a memory tag), its range and its size.
2. `xl_load(path)` gives the room for the host part back and calls `dlopen`: dyld takes the first hole that fits, which is
   the one just given back. It then calls the library's `xl_library_init`, which checks the header again and that the guest
   range is still an untouched reservation, maps the segments, writes the slots, and loads the registry.
3. Failures are statuses with a message (`xl_load_error`): a bad image or a format version the loader does not read, a
   busy range, a failed `dlopen`, a failed mapping. The host app decides what to do; nothing in the loader aborts it, and a
   library that was not reserved refuses to map anything, so it cannot write over memory that is not its own.

### The registry

libobjc registers the classes of an image while `dlopen` loads it: it reads the class structures from the image's
`__objc_classlist`. The guest's class structures are in the guest image, which the library maps only after dyld has placed the
host part and relocated the slots that point into it (the `isa` and the superclass of a guest class refer to symbols
that are known only then). A list in the host dylib would therefore be read before the classes exist, and the process
crashed in `dlopen` when it was tried.

So the lists are in a second, tiny dylib, `<name>-classes.dylib`, next to the library: the sections `__objc_classlist`,
`__objc_protolist`, `__objc_catlist` and `__objc_imageinfo`, no code. `xl_library_init` `dlopen`s it as its last step
before the guest's initializers run, when every class structure is in place, and libobjc registers the guest's classes
from it. The second dylib is found by a rule (the name of the library without `.dylib`, plus `-classes.dylib`), and
`xl_reserve` refuses a library that has none next to it. If that `dlopen` fails the status says so, and nothing was
registered: the registry is what registers, and it has no side effects before it is loaded.

The host dylib exports the structures of the guest's categories (`xl_objc_category_<n>`), because the registry's category
list refers to them by symbol and dyld binds them when the registry is loaded.

The only other exports of the library are `xl_library_init` and `xl_library_diagnostics`. The guest's symbols stay inside, so a
library never takes a name from the host's own images or the other way round.

## The runtime inside someone else's process

The runtime was written for a process of its own. Under `XL_LIBRARY` its process-wide parts are gone or opt-in:

- No `main`, no constructor, no `atexit` hook. The crash handlers, the alternate signal stack and the exit note are
  installed by `xl_library_diagnostics()` only if the app asks.
- `xl_setup` keeps the core (layout fixes, shadow tables, bridge tables). The application setup (uncaught exception
  handler, load rules, layout wrapping, storyboard classes) belongs to an executable and stays out.
- The dyld image callbacks are not forwarded to the real dyld, so the host's own images are not announced to the guest.
- The guest initializers and the bridge tables are set up lazily, by the first host-to-guest transition: every
  `xl_invoke` and `xl_invoke_n` begins with `xl_ensure_ready`. It is a mutex with an atomic ready flag, and a thread
  that is already initializing may re-enter it (an initializer that calls back into the guest).

## The guest in a foreign process

- **Threads.** A thread that enters the guest gets its own `State` with a 16 MB guest stack (virtual, touched on use)
  and a fake thread-specific data block for `TPIDRRO_EL0`, as in an executable. The guest creates no thread of its
  own except through the host's `pthread_create` and Dispatch, so the thread count of the host grows by the host's
  workers that run a guest block.
- **Classes.** The classes of the library are registered with the host's Objective-C runtime when the library loads,
  under their own names. An app reaches them with `NSClassFromString`, only after `xl_load` has succeeded. A Swift
  class with an Objective-C ancestor is a host object with a twin (`XL_SWIFT_HOST_ANCESTORS`); a block parameter of a
  public method needs the library's own header in the translator's includes file, because the type encoding of a
  block has no signature.
- **`NSBundle.mainBundle`.** The guest calls the host's `NSBundle`, so it sees the app's bundle, bundle id and
  `Info.plist`; nothing is copied.
- **Names.** The guest `libswiftCore` and the overlays next to the library's own image are registered with the host's
  Objective-C runtime beside whatever Swift runtime the host app has loaded, and the two have classes of the same names
  (`__SwiftValue`, `_TtCs12_SwiftObject`, `__SwiftNativeNSArrayBase`, the array and string storage classes). With one name
  for two classes the Objective-C runtime keeps one of them, and the host's Swift, which looks these classes up by name to
  box a value or bridge an array, can be handed the guest's class and read a layout it does not have. So the classes of
  every guest image but the first are registered under a prefix (`XLG.` by default, `XL_NAMESPACE`): the translator writes
  the prefixed name into the class, the runtime registers the shadows of the Swift classes and the classes the guest
  runtime makes later (a generic instantiation of one of its own classes, known by the module in its mangled name) under
  the same prefix, and the three ways the guest asks for a class by name are bridged. `objc_getClass` and
  `objc_lookUpClass` look a name up under the prefix first, and for a name that belongs to the namespace only there, so the
  guest never receives a class of the host; `class_getName` hands the guest the name without the prefix. The guest sees its
  runtime under the names it knows, the host sees only its own, and the classes of the library's first image, the ones a
  host reaches by name, keep their names. If a name is taken anyway (a host class with the prefixed name), the shadow is
  registered under `<name>@<guest address>` instead of stopping the load.

## What it does not do

- It does not make the library smaller. The lifted `libswiftCore` is almost all of the 119 MB of the Swift variant. Code
  that is mapped and never run costs no resident memory (measured), so a dead-strip by reachability from the SDK
  would shrink the file and the address window, not the resident set.
- It does not share a guest `libswiftCore` between two libraries. One library holds one guest runtime.
