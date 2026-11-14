# How the recompiler works

The recompiler lifts each arm64 function to LLVM IR (via [Rellume](https://github.com/aengelke/rellume)), rewrites
the Objective-C class, protocol and ivar metadata and the data binds for the 32-bit runtime, re-emits the code as
armv7, and links it against a small support runtime plus generated ABI bridges. The result is an ordinary armv7
Mach-O that a real iOS 6 device (or an emulator) loads and runs as a normal app.

## The pipeline

| Component | Role |
|---|---|
| `src/xlate/` | Lifts arm64 to LLVM IR (Rellume), recovers jump tables, rewrites Objective-C class, protocol and ivar metadata and data binds to the 32-bit layout, and emits `lifted.bc`. |
| `src/xlate/` (`xlgen`) | Generates the guest-to-host ABI bridges (calling convention, `va_list`, blocks, Objective-C message dispatch, data-symbol shims) from the SDK headers. |
| `src/runtime/` | The armv7 support runtime: message routing, block bridging, weak references, ivar-layout reconciliation and Objective-C compatibility shims. It is compiled per translation, because it includes the state header that xlate writes for each app. |
| `tools/translate.lua` | The end-to-end pipeline: arm64 executable to armv7 iOS 6 executable. |
| `tools/ipa.lua` | The same for a whole `.ipa`, its embedded frameworks lifted as guest images. |
| `tests/` | Small self-contained test programs and apps, the translator's regression suite. |
| `tests/perf/` | The on-device translated-versus-native benchmark. |

Rellume, farmdec and BlocksRuntime are packages of the package repository, pinned by commit with our changes as patches.
Rellume is built for AArch64 only, the one architecture xlate lifts.

The guest keeps its arm64 memory image, rebased below 4 GiB. Code runs natively as armv7. Only the crossings into
the system frameworks go through bridges.

## What a lifted function is

Rellume lifts a function from its start with every block that its direct branches reach, so the unit of lifting is the
control-flow graph, not the symbol. Two cases made the same code appear in many lifted functions, and both are handled
in xlate with changes to Rellume ([patches 0012 and 0013](../../../packages/r/rellume/patches)):

- **A jump table's targets are entries of the function that holds the table.** A `switch` compiles to an indirect jump
  whose targets are not function starts, so each one used to be lifted as a function of its own, with a copy of the
  tail that all the cases share. Now the function has several entries: its first block loads `pc` and switches to a
  stub per entry that unpacks the registers and branches to the entry's block, and a block that several entries reach
  exists once. An indirect jump that can still reach such a target enters the function again with a `switch` on `pc`.
- **A branch to the start of another function is a tail call.** The decoder stops at an address that
  `LC_FUNCTION_STARTS` lists, and the branch becomes a call of that function that keeps the stack constant (`musttail`,
  through `xl_tail` when the address is not known to be a function). Without this, a chain of N functions that each end
  in a `b` to the next was N(N+1)/2 copies. In a function that has landing pads the call is a plain call; see the
  exceptions entry of [decisions in the translator](#decisions-in-the-translator) for why that does not change which
  pad an exception reaches.

In the reCAPTCHA Enterprise SDK with its guest images the two changes took the lifted code from 6.84 million guest
instructions for 2.10 million different ones to 2.11 million, and the library from 142.96 to 51.76 MiB. `xlate
--report-duplicates` prints the numbers for any input.

## Status

- OneBusAway 2.3.2, the official arm64 App Store IPA, recompiles to armv7 and iOS 6 and reaches its full, interactive
  main screen: map view, search bar, tab bar, a native `UIAlertView`, and touch input. It has no app-specific rules
  and no source changes.
- On an iPhone 4S (A5) the translated compute kernels run at a geometric mean of about 1.9 times native armv7 (1.05
  times for memory-bound hashes, up to about 2.9 times for pointer-chasing). The translation machinery adds a few
  hundred KB resident.
- A second app, an xkcd reader that statically links Realm and a crash reporter, drove out several universal
  translator fixes: resilient lifting, floating-point data-symbol bridging and automatic long-call fallback for large
  binaries. They are described under [decisions in the translator](#decisions-in-the-translator).

## Classes the Swift runtime lays out

Swift keeps its class metadata in the platform's `objc_class` layout (arm64: isa, superclass, two cache words, a data
word with the `class_ro_t` and the Swift flags, then Swift's own fields) and reads those fields itself. iOS 6's libobjc
has a 32-bit `objc_class`, cannot read such an object, and has none of the calls the Swift runtime uses to give it its
classes. A class the guest lays out in that layout therefore keeps it, and the host runtime gets a **shadow**: an
ordinary host class built from the guest's `class_ro_t` (name, superclass, instance and class methods, instance size).
The bridge translates a class to and from the shadow where it crosses (`xl_class_in`, `xl_class_out`: a receiver, an
argument, a result). Nothing writes to the guest object, so what Swift reads from it stays true. The code is
`src/runtime/swift_classes.m`.

- A shadow is made when the Swift runtime hands a class over, through the calls the bridge provides because iOS 6
  lacks them (`_objc_readClassPair`, `__objc_realizeClassFromSwift`, `_objc_setHook_lazyClassNamer`,
  `_objc_setHook_getImageName`; `src/runtime/bridge-provides.txt`). It is made at start-up for a class the compiler listed in
  `__objc_classlist` (a device registers those when it loads the image, so a lookup by name finds them), and the first
  time a message or a call reaches a class the compiler laid out statically and listed only in `__objc_clsrolist`,
  which is when a device realizes it.
- A class the `ro` gives no name (a generic class instantiated at run time, or a prespecialized one) is named by the
  Swift runtime's own lazy class namer, which the shadow builder asks. The name is the runtime's, not a copy of its rule.
- Only Swift classes whose whole ancestry is the guest's own move to this layout (`SplitGuestLayoutClasses` in
  `src/xlate/objc.cpp`). A Swift class with a host ancestor, an `NSArray` subclass for instance, and every Objective-C
  class keep the host layout that the class list rewrite gives them, because host code sends their instances messages.
  What Swift reads from the fields that the rewrite overwrites (its superclass at +8 is the host's cache and vtable
  words, its data word at +32 is zero) is not what it wrote. A Swift `init` or `dealloc` thunk of such a class
  builds an `objc_super` from `swift_getObjectType(self)`, so it fails on the host layout.
- With `--swift-host-ancestors` (`XL_SWIFT_HOST_ANCESTORS=1` for `translate.lua`) a Swift class with a host ancestor
  moves too, in every image that is not a runtime image: a `--replaces` target, the bridge, or an image that exports
  `swift_allocObject`, the Swift runtime itself, whose own classes keep the layout they have. The class
  then has two classes, a **twin pair**: the guest's own, untouched (what Swift reads), and a host shadow whose
  superclass is the host ancestor, with a copy of the Swift part of the guest's class after its 20 bytes
  (`objc_allocateClassPair`'s extra bytes). An instance is a real host object (its isa word is the shadow), so host code
  can message it, and `NSObject`'s own methods work on it. The guest's class gets a guest-layout twin of the host
  ancestor as its superclass, so the Swift runtime can walk the ancestry. The twin is what the guest is told the host
  class is only from the moment a Swift class with that ancestor is built (`xl_publish_twins`). Before that, and in a
  program whose classes are all Objective-C, the host class goes out under its own address, the one that its symbol and
  `objc_getClass` give, so `class_getSuperclass` of a guest class and `object_getClass` of an `NSObject` agree with
  `&OBJC_CLASS_$_NSObject`; the runtime used to make the twin for every shadow and hand it out at once, and such a program
  met two classes named `NSObject`. A program with Swift classes of a host ancestor still has both names once the twin is
  published. A class of the guest's own image is never given a twin: an executable's image is known to `dladdr`, and a
  library's, which the loader maps itself, is known by its range (`xl_guest_low`, `xl_guest_high`). The runtime keeps the tables in both directions
  (`xl_guest_to_host`, `xl_host_to_guest`, `xl_host_twin`, `xl_twin_host`) and the bridge translates at each crossing, as it
  does for a shadow. The copy of the Swift part is made when the shadow is built and made again before `+alloc`
  (`xl_swift_sync_class`), because the Swift runtime writes into its class when it first uses it. The host's libobjc
  does not run the guest class's `.cxx_destruct`, which destroys the stored properties of a Swift class, for a class it
  did not read from an image; the runtime runs the guest's `.cxx_destruct` of each shadow in the instance's ancestry
  when the last `[super dealloc]` leaves for a host class (`xl_swift_super_dealloc`), and a shadow whose guest class has no
  `-dealloc` of its own gets one that does the same before it calls its superclass's. A class compiled for
  iOS 12.2 or later marks itself Swift with bit 1 of its data word, not the bit 0 of the guest's libswiftCore (built with
  `-DSWIFT_CLASS_IS_SWIFT_MASK=1ULL`); the runtime rewrites the bit when it sets the class up.
- The superclass of a Swift class can be a Swift class whose layout the host keeps (`__ContiguousArrayStorageBase`, which
  derives from `NSObject`, so the pair split leaves it alone). A class that the Swift runtime builds at run time
  (`_ContiguousArrayStorage<T>`, `_DictionaryStorage<K, V>`) copies the superclass's instance size, alignment mask and
  vtable from the metadata of the superclass only when that metadata is the guest's; the runtime therefore
  reconciles the new class with its superclass when it registers the shadow (`xl_reconcile_swift_super`). For any such
  superclass it raises the alignment mask, moves the instance start behind the superclass's instance, shifts
  `ro->instance_size`, the metadata's own size and the field offset vector by the same amount, and fills the vtable
  slots the class left empty from the superclass. The three consumers of the size agree afterwards: `swift_allocObject`
  reads the metadata, the host's `class_getInstanceSize` reads `ro`, and the field accessors read the offsets. A class
  whose size is smaller than its superclass's, or whose metadata is shorter, stops the program with the class named.
- A shadow cannot give the host an *instance* that the guest allocated. The instance's isa word is the guest class, so
  the bridge looks the shadow up when a guest message reaches it and answers `-retain`, `-release` and
  `-autorelease` with the guest's own methods. A host method of a shadow's ancestry (`-[NSObject isEqual:]`) sent to
  such an instance, or host code that meets one (`CFRetain` from an array), still faults in libobjc. A class object
  the guest holds is not reference counted: the bridge answers those three with the object itself. The bridge also
  translates every `Class` it passes or returns for a host function (`class_createInstance`, `objc_getClass`) the way
  it does an `id`. A shadow carries
  no protocols, properties or ivars yet; a class that has any says so in the shadow log (create
  `/private/var/revenant/xl-shadow-log` on the device, then read `xlate-shadow.log`). A method a shadow adds is a block
  IMP that carries `self`, the selector and four more words to the guest method.

`tests/classpair` builds the cases as a program for macOS, where objc4 is the real thing, and the translation must
print on the iPad 2 what objc4 printed.

## Decisions in the translator

- **Ivar layout never shrinks.** The translator never slides guest ivars down when the host superclass is smaller
  than the arm64 one. The lifted code addresses ivars with arm64 offsets, so a shrunken instance leaves the last
  ivar's 8-byte slot past the allocation, and memory is corrupted nondeterministically. OneBusAway found this.
- **Floating-point data symbols** such as `NSFoundationVersionNumber` and `UIWindowLevelNormal` are bridged through
  a copy of the guest's globals that is filled at startup, in the guest's float width.
- **Large binaries are split, and the globals stay whole.** A module of more than 6 MB of bitcode (`XL_OBJECT_BYTES`)
  is split into pieces of about that size. Two limits ask for it. Direct calls reach 32 MB, so the pieces let ld64
  insert branch islands between them. And an armv7 Mach-O scattered relocation addresses 24 bits of a section: a
  function with a landing pad registers its SjLj frame with the label difference between `__text` and
  `__gcc_except_tab`, which is one, so an object whose `__text` passes 16 MB fails with "can not encode offset ... in
  resulting scattered relocation". Lifted bitcode becomes 1.0 to 1.25 times as many bytes of object, and the pieces
  `llvm-split` makes differ by up to 1.5 times, so a 6 MB budget keeps the biggest piece below 12 MB. All globals (the
  rehosted guest image and the Objective-C metadata) stay in one data object at their single-object layout, and only
  the functions are distributed into code-only pieces, using `llvm-extract --delete`. The lifted code reaches guest
  memory by absolute address and the metadata cross-references its own class objects. A global moved to another
  piece leaves `__objc_classlist` pointing at the wrong class objects, and the image crashes inside objc's
  `map_images`, before any handler is installed. Small apps take no long calls, no text relocations and no cost.
- **C++ runtime.** `__cxa_atexit` is bridged: the guest's static destructor is recorded and run through the runtime,
  not the host C++ runtime. `operator new`, `new[]`, `delete` and `delete[]` go to the host allocator.
  `recompiler/tests/cxxinit` is the regression test: a global C++ object with a `std::string`, a `std::vector` and a
  destructor.
- **Exceptions.** Objective-C and C++ exceptions pass through lifted frames, from guest code to guest code and from host
  code to guest code. The host armv7 runtime unwinds with setjmp/longjmp function contexts, and a lifted function has
  none, so xlate reads the guest's `__unwind_info` and LSDA (and the `__eh_frame` entry of a function the compact
  encoding cannot describe) and turns every lifted call that has a landing pad into an `invoke`. Its unwind edge is a
  `landingpad` that names the host's own personality routine (`__objc_personality_v0`, `__gxx_personality_sj0` or
  `__gcc_personality_sj0`) with the catch types of the LSDA: the host's `OBJC_EHTYPE_*` objects for an imported class,
  a type object built from the guest's metadata for a class the guest defines, null for a catch-all. LLVM registers the
  function context and writes the host's call-site table, so the host personality does the matching. At the pad the
  callee-saved registers and the stack pointer come back from a snapshot taken before the call, and the guest's landing
  pad runs as a lifted function with the exception in `x0` and the selector in `x1`. A pad inside such a continuation
  does not nest another host frame: it leaves a marker in the program counter and returns, and one loop calls the next
  continuation, so a loop that catches thousands of exceptions keeps a constant stack. `objc_begin_catch`,
  `__cxa_begin_catch`, `__cxa_end_catch`, `__cxa_rethrow` and `__Unwind_Resume` go to the host; the last one calls
  `_Unwind_SjLj_Resume`, because iOS 6 has no `_Unwind_Resume`. xlate prints how many call sites in how many functions
  unwind to how many landing pads, and counts the ones it left as plain calls (an exception specification, an
  unknown personality, a function that mixes personalities). A `throw` of translated C++ code (`__cxa_throw`) is a
  fault, and a catch of a C++ class the guest itself defines cannot match a host exception, so that clause is dropped.
  A tail call (`musttail`) in a function that has landing pads becomes a plain call, and a plain call has the call-site
  index -1 in the SjLj context, so an exception that leaves the callee does not dispatch to a pad of the caller: the
  native branch that made the call a tail call had already given the caller's frame back
  (`recompiler/tests/libexceptions`, `stepTail`). `recompiler/tests/exceptions` is the regression test.
- **Callbacks into the guest.** A thread has one set of guest registers, and host code that calls a guest function runs
  it on that set: a method libobjc dispatches (`+initialize`, a delegate method, `+class` of a guest root class), a
  block, a C callback, a hook. Every such call goes through `xl_invoke` or `xl_invoke_n`, which restore the program
  counter, the link register and `x0` to `x7` and return the callee's `x0`; a callback pays for nothing else, and the
  one that a C library makes for every comparison of a sort is the hot one (722 ns on the iPhone 4S). A message send in
  flight depends on more than that. `objc_msgSend` routes with the arguments still in the registers (`x0` to `x7`, the
  `x8` of a structure result, `v0` to `v7`) and then jumps to the guest method or to the selector's bridge, and routing
  itself runs guest code: the shadow of a statically laid out class is built when the first message reaches it, which
  asks the lazy class namer and sends `+class` to the superclass, and libobjc sends `+initialize` before it answers with
  the method. A callback that left its own values behind made the message arrive with them. The first `objc_opt_self` of
  a prespecialized `_IndexBox<Int>` returned `_SwiftObject`, the result of that `+class`, so the first index box was
  allocated with a class that has no Swift destroy function, and every `Mirror`, `String(describing:)` and
  `AnyCollection` died on it. So the three places that route and then enter guest code with the arguments they were
  given (`objc_msgSend`, `objc_msgSendSuper2` and the entry of an `IMP` that the guest holds) save `x0` to `x8` and `v0`
  to `v7` before they route and put them back after it; the cost falls on the message that routes, where the copy is
  small beside the lookup, and not on every callback. On the iPhone 4S, copying the whole register file in `xl_invoke`
  made the comparator callback of `qsort` 1470 ns, and copying only the argument registers there 1130 ns, against 722
  ns. With the copy in the routing handlers the callback stays at 722 ns, and a message to a guest method takes 8.7 µs
  where the whole-state copy that the routing used to make around `class_getMethodImplementation` took 9.5 µs. The copy
  is `__builtin_memcpy_inline` (NEON loads and stores): a loop of 64-bit integer moves, which the compiler cannot turn
  into a call, measured 8.9 µs to 9.0 µs.
  `recompiler/tests/classpair` has both cases: the first message to a class laid out only in `__objc_clsrolist` under a
  guest root class, and a first message with integer, floating-point and structure-result registers to a class whose
  `+initialize` is guest code.
- **Blocks the guest hands to the host.** A block parameter of a host function is converted into a host block that holds a
  copy of the guest block (`Block_copy` in the guest) and invokes it. The host block is the callee's for the call: the
  generated stub takes it with a count of +1, and the one holder of the guest copy belongs to that block alone, so both
  go when the stub returns the block; an API that keeps the block past the call (`dispatch_async`) has copied it, and the
  copy keeps the holder and the guest block until the host lets go. An autoreleased block or holder would keep the guest
  copy, and everything it captured, until some pool drained, and Swift's `withoutActuallyEscaping`, which
  `DispatchQueue.sync` is written with, checks that the closure context is unique after the body and stops the process
  if it is not. `recompiler/tests/hostbridges` has both cases (the `block sync` and `block async` lines).
- **Method implementations (`IMP`).** An `IMP` is a bare code address, and the guest and the host disagree on what one
  means. A guest method's `IMP` is the guest function, and the host reaches it through a block `IMP` that
  `class_addMethod`, `class_replaceMethod` and `method_setImplementation` build (`xl_host_imp_for_guest`, cached per
  guest function and selector; only `self`, `_cmd` and up to four 32-bit word arguments cross, anything else is an
  `xl_unsupported` with the reason). A host `IMP` that reaches the guest (`class_getMethodImplementation`,
  `method_getImplementation`, `imp_implementationWithBlock`, the old `IMP` that `class_replaceMethod` and
  `method_setImplementation` return) becomes a unique fake guest address in a region the runtime owns
  (`xl_imp_region`, 4096 slots; one `IMP` asked for twice gets the same address). `xl_lookup` falls back to
  `xl_imp_lookup` for an address in that region, and the entry finds its slot from the program counter, routes the
  call through the same bridge a message send would use (`xl_bridge_for`, by the type encoding of the method) and
  sets a thread-local forced-`IMP` key that the generated message bridge takes (`xl_take_forced_imp`), so that exact
  `IMP` runs and not the dynamic dispatch of the receiver. An `IMP` that the guest implements maps straight back to its
  guest function. A block `IMP` has no selector and cannot be called as a function from the guest; that is a fault.
  `dladdr` on such an address names the runtime image.
- **`scanf` family.** The guest `long`, `size_t`, `ptrdiff_t`, pointers and `%n` are 8 bytes and the host's are 4. The
  varargs of `scanf`, `sscanf` and `fscanf` are read into host temporaries for the conversions that differ, the call
  goes to `vscanf`, `vsscanf` or `vfscanf`, and the temporaries are widened back into the guest's variables only for
  the conversions the call completed (`xl_scanf_marshal`, `xl_scanf_finish`).
- **`getaddrinfo`.** The guest `struct addrinfo` is 48 bytes and the host's 32. The result list is converted into a
  `calloc`ed array of guest-layout nodes behind a header (the host list and a magic); `ai_addr` and `ai_canonname`
  point at host data, and `freeaddrinfo` finds the header by its magic and frees both lists.
- **`class_copyMethodList`.** The host returns an array of 4-byte `Method` pointers; the bridge widens it into
  8-byte slots in place of the host array and stores the count.
- **Pointers to host constants that are 4 mod 8.** The guest Swift runtime clears the low three bits of an object
  pointer (a bridged `String`, an `Array` of objects keep tags there), so an object that the host hands out at an address
  that is not a multiple of 8 comes back as another object. The host's `malloc` blocks, its singletons (`kCFNull`,
  `kCFBooleanTrue`, `kCFBooleanFalse`, the `@YES` and `@NO` numbers, the `kCFAllocator*` allocators, the classes, the
  dispatch queues) are measured 0 mod 8 on the 4S. What is not: the constant strings (`__NSCFConstantString`, the
  `__DATA,__cfstring` section of an image whose section starts at 4 mod 8, which is every constant of CoreFoundation,
  Security, SystemConfiguration, IOKit and of the app itself, `NSDefaultRunLoopMode`, `kCFRunLoopDefaultMode`,
  `NSLocaleLanguageCode`, `NSInvalidArgumentException`) and some `Protocol` objects (`@protocol(NSObject)`).
  `src/runtime/alignment.m` gives the guest an **alias** instead: for a constant string a copy made with a private
  `CFAllocator` over a 4 MiB arena (CoreFoundation puts a 4-byte allocator word in front of the object, so the arena
  hands out blocks at 4 mod 8 and the object lands on a multiple of 8; the copy is a real `__NSCFString` with the same
  characters; CoreFoundation answers a few strings (`gregorian`) with the constant it already has instead of a new object,
  and the runtime then makes a mutable copy through the same allocator), for a `Protocol` a 16-byte shell that holds the isa word and the name, which is also what `xl_protocol`
  reads. The cache constant to alias is made once under a lock and kept; the same constant is the same alias for every
  caller and every thread. Each alias sits in the arena behind an 8-byte header that holds the original and a check word,
  so the other direction is a range test of the arena (`xl_narrow_pointer`, `xl_object_in`): the host gets the original
  constant back and never sees an alias. One funnel serves every host-to-guest path: `xl_object_out` for objects,
  `xl_widen_pointer` for plain pointers (a value that is 4 mod 8 is looked up in the constant ranges of the loaded
  images, which the runtime reads from dyld's image list and reads again when the image count has changed; it does not
  ask dyld for a callback, because the runtime defines `_dyld_register_func_for_add_image` itself for the guest images and
  in library mode never forwards it to the host's dyld), and `xl_protocol_out` for `Protocol`; the generated
  bridge (returns, out slots, record fields, data imports, callback and block slot arguments) and the bridges by hand
  (dynamic message returns, fast enumeration, the weak-reference functions, the variadic collection constructors, the
  arguments and result of a guest block the host calls, the word trampoline of a guest method) call them. An object at
  4 mod 8 that is neither a constant string, nor a protocol, nor a class stops the program with its class named.
- **What an import of a guest image becomes.** `xlgen` sorts every symbol that no guest image defines by what differs
  between the arm64 guest and the armv7 host, and a symbol it cannot place is `UNSUPPORTED` in `report.txt`, is
  printed by the translation, and aborts with its name if the guest reaches it: nothing is stubbed to look like it
  worked.
  - *Same ABI*: the declaration is in `include/common-includes.h` and the call goes through the generated bridge
    (`lgamma_r`, `__snprintf_chk`, `asprintf_l`, `snprintf_l`, `sem_open`, `open_dprotected_np`, `copyfile`,
    `catgets`, `pthread_key_init_np`); variadic functions with a format get their `va_list` variant, and `strftime_l`
    has a format of dates, which the bridge does not read.
  - *Layout differs*: a bridge by hand in `src/runtime/bridge.m`, with a case in `tests/hostbridges` that the Mac and
    the 4S answer alike. `CGColorCreate`, `CGColorGetComponents`, `CGImageCreateWithMaskingColors` (`CGFloat` is a
    `double` here and a `float` there; the count of components comes from the colour space; the array that
    `CGColorGetComponents` returns is the runtime's, one per colour and refilled at each call, so it stays valid as long
    as the colour does); `__NSGetArgv` (a 64-bit copy of `argv`, made at the first call, so a store through the
    returned pointer changes the copy); `getifaddrs`/`freeifaddrs` and `getservbyname` (guest-layout lists behind a
    header, as `getaddrinfo`; the `if_data` of a link entry is copied with the 8-byte `timeval`); `localeconv_l` (one
    guest `struct lconv` per locale); `class_copyIvarList` (8-byte slots, as `class_copyMethodList`); `swprintf` (the
    format and the arguments are read as `printf` reads them, through UTF-8, and `vswprintf` gets the host's).
  - *Opaque handles*: `catopen` returns an `nl_catd`, `malloc_default_zone` and `malloc_zone_from_ptr` return a
    `malloc_zone_t *`, and `copyfile_state_alloc` a `copyfile_state_t`, which the guest only hands back (libswiftCore's
    `-[_SwiftObject zone]` answers the zone, libc++'s `messages` passes the catalogue to `catgets` and `catclose`,
    libc++'s `std::filesystem` copy gives the state to `fcopyfile` and `copyfile_state_free`). They cross as the host's pointer, and `-1` crosses as
    `-1`. A guest that read a zone's function table would read 4-byte pointers: none of these images does.
  - *Data*: `__progname` is a copy of the host's pointer, filled at start-up. `NSDataDeallocatorFree`, `Unmap` and `VM`
    are private blocks of Foundation that iOS 6.1.3 does not have; the guest gets blocks of its own that call `free`,
    `munmap` and `vm_deallocate`, which is what Foundation's blocks do (nothing on a null pointer for the last two).
    `_dispatch_source_type_vm` is the host's. `__swiftImmortalRefCount` is an absolute symbol of libswiftCore
    (`0x80000004ffffffff`): a bind to it takes the value, unslid.
  - *A function that returns at once*: `__chkstk_darwin`, the stack probe that an arm64 Darwin function with a large
    frame calls first, with the size in `x9`; it keeps every register but `x16`, `x17` and the flags, and touches
    each page of the new frame from the stack pointer down so that a frame cannot jump over the guard page. The
    lifted code runs on the host thread's stack, which has the same guard page; a frame that fits behaves the same
    without the probe, and one that overflows stops at a page below the guard or in memory beside the stack instead of
    at the guard itself.
  - *Not implemented, and loud*: `__Unwind_RaiseException`, which libc++abi's `__cxa_throw` calls. A C++ exception
    thrown by guest code has a `__cxa_exception` of arm64 layout that the host's personality cannot read, so the
    throw is a fault, as `__cxa_throw` of an imported libc++ is.

## Scope and limits

- A translated program can also be built as a library that an app loads into its own process, at fixed addresses
  (`XL_LIBRARY=1`); see [library mode](library-mode.md).
- The AES, SHA-1 and SHA-256 instructions of the ARMv8 Crypto extension, `PMULL` and the half-precision `FCVT` are lifted
  to calls of C helpers in the runtime, because armv7 has no instruction to lower them to
  ([the helpers](../../reference/recompiler/lifted-helpers.md)). SHA-512 and SHA-3 are not lifted: the iOS 6 target does not
  have them, and the one SHA-512 routine in the SDK images is behind a capability bit that the target never sets.
- Objective-C and C are supported. Swift is being brought up on a demo app, with `libswiftCore` lifted as a guest
  image. It does not run to the end yet, and what a Swift program meets is measured one failure at a time. Swift
  metadata is 64-bit only, so the Swift runtime needs a separate effort.
- A very large translated binary (100 MB and more, such as the Realm-linked xkcd reader) links through the module
  split above and loads on a real iOS 6 device. The bundled emulator's dyld faults on such an image; that is an
  emulator limit, not a size or translation limit. An app that then references iOS 7+ system symbols, as xkcd does
  through `NSURLSession`, stops at dyld symbol binding, which belongs to the backports.
- iOS 7+ system APIs that the app calls must exist on the target. Ones that do not are reported, not stubbed; they
  belong to the backports.
- Functions that cannot be lifted (hand-written assembly in crash reporters, for instance) become traps that fault only
  if they are actually called.
- The lift is deterministic: `xlate`, `llvm-split` and the linker give the same bytes for the same input. The final
  armv7 objects are not always. The stock LLVM's SjLj preparation (the armv7 iOS 6 unwinder) demotes the phis of a
  landing pad in the order of their addresses once there are more than eight, so the stack-slot order, and with it the
  frame layout and the size of the object, differ from run to run for a function with such a landing pad. Two builds of
  the same reCAPTCHA Enterprise SDK image differed by 448 bytes of `__text` (36,007,928 and 36,007,480) and behaved
  the same. Compare two builds by what they do, not by their hashes, until the llvm package carries a fix. The fix is a
  one-function patch to LLVM; it moves the package's key, so it waits for a prebuilt release of the new key.
