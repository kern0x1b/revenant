# Changelog

All notable changes to Katabasis. This project is a research prototype; versions
are informal.

## Unreleased

### Milestone
- OneBusAway 2.3.2 (official arm64 App Store IPA) recompiled to armv7/iOS 6 reaches
  its full interactive main screen, rule-free, and responds to touch input.
- On-device benchmark (iPhone 4S / A5): translated compute is ~1.9× native armv7
  (geomean); translation-machinery resident overhead ~0.4 MB.

### Universal translator fixes
- **ivar layout**: never slide guest ivars *down* when the host superclass is smaller
  than the arm64 one; the lifted code addresses ivars with arm64 offsets, so shrinking
  the instance size left the last ivar's 8-byte slot past the allocation and corrupted
  memory nondeterministically. (Surfaced by OneBusAway.)
- **resilient lifting**: a function Rellume cannot model (e.g. hand-written crash-reporter
  assembly) is skipped and becomes a runtime trap, instead of aborting the whole build.
- **floating-point data symbols**: bridge system `double`/`CGFloat` globals
  (`NSFoundationVersionNumber`, `UIWindowLevelNormal`, ...) via a startup-filled guest
  copy in the guest's float width.
- **scale / module splitting**: a large app (e.g. an xkcd reader that statically links
  Realm) can lift into a single object whose inter-function BL branches exceed the armv7
  ±32 MB range. When the direct-call compile hits "Relocation out of range", the module is
  split so ld64 can insert branch islands between pieces — but the split keeps *all* globals
  (the rehosted guest image and the Objective-C metadata) in one data object at their
  single-object layout and distributes only the functions into code-only pieces. This is
  essential: the lifted code reaches guest memory by absolute address and the metadata
  cross-references its own class objects, so a global that `llvm-split` moved to another
  piece (or duplicated into one) would leave `__objc_classlist` pointing at the wrong class
  objects and the image would crash silently inside objc's `map_images`, before any handler
  is installed. Fixed by separating data and code with `llvm-extract --delete` (globals in
  one object, functions split); no long calls, no text relocations, no cost for small apps.
- **C++ runtime ABI**: bridge `__cxa_atexit` (static-destructor registration — the guest
  destructor is guest code, recorded and run via the runtime, not the host C++ runtime) and
  operator `new`/`new[]`/`delete`/`delete[]` (to the host allocator), so translated C++ code
  initializes and allocates. Exception unwinding (`__gxx_personality_v0`, `__cxa_begin_catch`,
  `_Unwind_Resume`) remains a trap, hit only if an exception propagates. Regression test:
  `corpus/cxxinit` (a global C++ object with a std::string/std::vector and a destructor).
- **backports binding**: link the apple-backports libraries before the stock frameworks so a
  translated app's iOS 7+ classes (NSURLSession, UIAlertController, ...) bind from the
  backports instead of the absent stock symbols; `-dead_strip_dylibs` keeps only the ones
  used. A framework the target lacks (e.g. WKWebView's WebKit) is weak-linked, so the image
  loads and faults only if that API is used. Gated on `BACKPORTS_DIR`.
- **jump-table recovery, va_list, Objective-C metadata, block bridging**: see `docs/research.md`.

### Known limitations
- Swift is not supported (Swift metadata is 64-bit-only; separate effort).
- iOS 7+ system APIs an app calls must exist on the target; missing ones are reported,
  not stubbed (separate backports effort).
- Very large translated binaries (100 MB+, e.g. the Realm-linked xkcd reader) link cleanly
  via module splitting and load on a real iOS 6 device (dyld maps all segments and reaches
  symbol binding). The bundled emulator's dyld faults on such an image — an emulator limit,
  not a size or translation limit. An app that then references iOS 7+ system symbols (xkcd
  uses `NSURLSession`, absent from iOS 6 Foundation) stops at dyld symbol binding; that is a
  missing-OS-API matter for a separate backports effort, not the translator.
