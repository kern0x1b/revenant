# Library mode

An app that links a translated library cannot start a second process for it: the reCAPTCHA token is bound to the app
(main bundle, bundle id, keychain, `Info.plist`). Library mode therefore builds the translated program as an armv7
dylib that an app loads into its own process, next to its own code and heap.

`XL_LIBRARY=1 ./xmakew l -P . recompiler/tools/translate.lua <input>.dylib includes.h out/ [guest images]` makes
`out/<name>.dylib` instead of an executable. [The reference](../../reference/recompiler/library-mode.md) has the
measurements; [the guide](../../guides/recompiler/build-and-translate.md#translate-a-library) has the commands.

## The constraint: a guest address is a host address

The guest keeps its arm64 memory image at its own addresses, and the lifted code reaches it by absolute address, so a
guest segment has to sit where it was linked. An executable gets that from `-segaddr` and `-no_pie`. A library gets it
from the layout below, and from a loader that checks it:

| Part | Address |
|---|---|
| host `__TEXT` and `__DATA` (the lifted code, the runtime, the bridges) | below the guest window, from `XL_BASE` minus a window sized to the lifted code |
| guest segments (`__X<n>TEXT`, `__X<n>DATA`, one pair per image) | from `XL_BASE` (default `0x10000000`) |
| `__LINKEDIT` | after the last guest segment |

dyld needs the segments in ascending order, and ld64 puts `__LINKEDIT` right after `__DATA` unless it is told where,
so `xlate --library` writes `-segaddr __LINKEDIT` after the guest window. The window below the base is the lifted
code plus 8 MB, rounded up to 16 MB; the link fails, naming `XL_BASE`, if that does not fit under the base.

ld64 links an armv7 dylib at an address only up to a limit: a guest window at `0x28000000` links and runs on the
phone, one at `0x48000000` or `0x50000000` is refused ("would make the output executable exceed available address
range"), though a plain dylib links there. The base of a library therefore lies below about `0x40000000`.

## Loading

What the phone's dyld (iOS 6.1.3) does with a preferred address was measured, not assumed:

- a dylib linked into the executable at launch is slid in a PIE process and honoured in a non-PIE one;
- a dylib that is `dlopen`ed at run time is placed at its preferred address in both, if the range is free.

The loader (`recompiler/src/loader/xl_loader.c`, `include/xl_loader.h`) is therefore a `dlopen` loader, linked into the
host app:

1. `xl_reserve(path)` reads the Mach-O header of the library and takes its whole range with `vm_allocate` at the fixed
   address, protected `VM_PROT_NONE`. An app calls it as early as it can: the heap, other images and threads fill an
   address space from the bottom, and a range that is free at launch is not free at login.
2. `xl_load(path)` gives the reservation back, calls `dlopen`, and, if that fails, takes the reservation again. It then
   calls the library's `xl_library_init`, which compares its own header with the link address. A library that dyld put
   anywhere else is refused for good (`XL_LOAD_RELOCATED`): its guest addresses would be wrong, and running it would
   corrupt memory instead of failing.
3. Failures are statuses with a message (`xl_load_error`): a bad image, a busy range, a failed `dlopen`, a relocated
   image. The host app decides what to do; nothing in the loader aborts it.

Only `xl_library_init` and `xl_library_diagnostics` are exported. The guest's symbols stay inside, so a library never
takes a name from the host's own images or the other way round.

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
