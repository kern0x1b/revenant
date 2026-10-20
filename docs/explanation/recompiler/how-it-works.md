# How the recompiler works

The recompiler lifts each arm64 function to LLVM IR (via [Rellume](https://github.com/aengelke/rellume)), rewrites
the Objective-C class, protocol and ivar metadata and the data binds for the 32-bit runtime, re-emits the code as
armv7, and links it against a small support runtime plus generated ABI bridges. The result is an ordinary armv7
Mach-O that a real iOS 6 device (or an emulator) loads and runs as a normal app.

## The pipeline

| Component | Role |
|---|---|
| `xlate/` | Lifts arm64 to LLVM IR (Rellume), recovers jump tables, rewrites Objective-C class, protocol and ivar metadata and data binds to the 32-bit layout, and emits `lifted.bc`. |
| `xlate/` (`xlgen`) | Generates the guest-to-host ABI bridges (calling convention, `va_list`, blocks, Objective-C message dispatch, data-symbol shims) from the SDK headers. |
| `runtime/` | The armv7 support runtime: message routing, block bridging, weak references, ivar-layout reconciliation and Objective-C compatibility shims. It is compiled per translation, because it includes the state header that xlate writes for each app. |
| `scripts/translate.lua` | The end-to-end pipeline: arm64 executable to armv7 iOS 6 executable. |
| `scripts/ipa.lua` | The same for a whole `.ipa`, its embedded frameworks lifted as guest images. |
| `corpus/` | Small self-contained test programs and apps, the translator's regression suite. |
| `perf/` | The on-device translated-versus-native benchmark. |

Rellume, farmdec and BlocksRuntime are packages of `third_party/`, pinned by commit with our changes as patches.
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
  binaries. [The changelog](../../reference/recompiler/changelog.md) lists them.

## Classes the Swift runtime lays out

Swift keeps its class metadata in the platform's `objc_class` layout (arm64: isa, superclass, two cache words, a data
word with the `class_ro_t` and the Swift flags, then Swift's own fields) and reads those fields itself. iOS 6's libobjc
has a 32-bit `objc_class`, cannot read such an object, and has none of the calls the Swift runtime uses to give it its
classes. A class the guest lays out in that layout therefore keeps it, and the host runtime gets a **shadow**: an
ordinary host class built from the guest's `class_ro_t` (name, superclass, instance and class methods, instance size).
The bridge translates a class to and from the shadow where it crosses (`xl_class_in`, `xl_class_out`: a receiver, an
argument, a result). Nothing writes to the guest object, so what Swift reads from it stays true. The code is
`runtime/swift_classes.m`.

- A shadow is made when the Swift runtime hands a class over, through the calls the bridge provides because iOS 6
  lacks them (`objc_readClassPair`, `_objc_realizeClassFromSwift`, `objc_setHook_lazyClassNamer`,
  `objc_setHook_getImageName`; `runtime/bridge-provides.txt`). It is made at start-up for a class the compiler listed in
  `__objc_classlist` (a device registers those when it loads the image, so a lookup by name finds them), and the first
  time a message or a call reaches a class the compiler laid out statically and listed only in `__objc_clsrolist`,
  which is when a device realizes it.
- A class the `ro` gives no name (a generic class instantiated at run time, or a prespecialized one) is named by the
  Swift runtime's own lazy class namer, which the shadow builder asks. The name is the runtime's, not a copy of its rule.
- Only Swift classes whose whole ancestry is the guest's own move to this layout (`SplitGuestLayoutClasses` in
  `xlate/src/objc.cpp`). A Swift class with a host ancestor, an `NSArray` subclass for instance, and every Objective-C
  class keep the host layout that the class list rewrite gives them, because host code sends their instances messages.
  What Swift reads from the fields that the rewrite overwrites (its superclass at +8 is the host's cache and vtable
  words, its data word at +32 is zero) is not what it wrote.
- A shadow cannot give the host an *instance* that the guest allocated. The instance's isa word is the guest class, so
  the bridge looks the shadow up when a guest message reaches it and answers `-retain`, `-release` and
  `-autorelease` with the guest's own methods. A host method of a shadow's ancestry (`-[NSObject isEqual:]`) sent to
  such an instance, or host code that meets one (`CFRetain` from an array), still faults in libobjc. A shadow carries
  no protocols, properties or ivars yet; a class that has any says so in the shadow log (create
  `/private/var/revenant/xl-shadow-log` on the device, then read `xlate-shadow.log`). A method a shadow adds is a block
  IMP that carries `self`, the selector and four more words to the guest method.

`corpus/classpair` builds the cases as a program for macOS, where objc4 is the real thing, and the translation must
print on the iPad 2 what objc4 printed.

## Scope and limits

- Objective-C and C are supported. Swift is being brought up on a demo app, with `libswiftCore` lifted as a guest
  image. It does not run to the end yet, and what a Swift program meets is measured one failure at a time.
- iOS 7+ system APIs that the app calls must exist on the target. Ones that do not are reported, not stubbed; they
  belong to the backports.
- Functions that cannot be lifted (hand-written assembly in crash reporters, for instance) become traps that fault only
  if they are actually called.
