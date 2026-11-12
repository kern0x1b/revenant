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
  ancestor as its superclass, so the Swift runtime can walk the ancestry. The runtime keeps the tables in both directions
  (`xl_guest_to_host`, `xl_host_to_guest`, `xl_host_twin`, `xl_twin_host`) and the bridge translates at each crossing, as it
  does for a shadow. The copy of the Swift part is made when the shadow is built and made again before `+alloc`
  (`xl_swift_sync_class`), because the Swift runtime writes into its class when it first uses it. The host's libobjc
  does not run the guest class's `.cxx_destruct`, which destroys the stored properties of a Swift class, for a class it
  did not read from an image; the runtime runs the guest's `.cxx_destruct` of each shadow in the instance's ancestry
  when the last `[super dealloc]` leaves for a host class (`xl_swift_super_dealloc`), and a shadow whose guest class has no
  `-dealloc` of its own gets one that does the same before it calls its superclass's. A class compiled for
  iOS 12.2 or later marks itself Swift with bit 1 of its data word, not the bit 0 of the guest's libswiftCore (built with
  `-DSWIFT_CLASS_IS_SWIFT_MASK=1ULL`); the runtime rewrites the bit when it sets the class up.
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
  `recompiler/tests/exceptions` is the regression test.
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

## Scope and limits

- A translated program can also be built as a library that an app loads into its own process, at fixed addresses
  (`XL_LIBRARY=1`); see [library mode](library-mode.md).
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
