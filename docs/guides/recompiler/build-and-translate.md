# Build and translate

## Build

The recompiler is part of the revenant xmake project; run everything from the top of revenant. Every tool comes from
a package. LLVM 23 with its libraries comes from Revenant's `llvm` package (its `libraries` config), built from source
on the first configure. Rellume, farmdec and BlocksRuntime are packages of the package repository. The iOS SDK (for the
header-driven bridge generation), `ld64` and `ldid` are Revenant's packages. The first configure builds LLVM, which
took 40 to 75 minutes on the machine it was measured on.

```sh
./xmakew f -P . -y
./xmakew build -P . xlate xlgen
```

## Translate an executable

```sh
./xmakew l -P . recompiler/tools/translate.lua path/to/app-arm64 includes.h out/
```

`includes.h` imports the frameworks the app uses. The output `out/<name>` is an armv7 iOS 6 executable; drop it into
the app bundle in place of the original.

A whole `.ipa` is translated with

```sh
./xmakew l -P . recompiler/tools/ipa.lua App.ipa includes.h out/App.ipa
```

The translator takes a compiled arm64 Mach-O, never source. For an app under `targets/` that means the decrypted
executable and frameworks of its released `.ipa`, never objects built from an edited copy of its source. `tests/` and
`tests/perf/` build their own arm64 input from their own source.

## Guest libraries, and what a bind names

Further arguments are guest images lifted with the executable:

```sh
./xmakew l -P . recompiler/tools/translate.lua app-arm64 includes.h out/ libA.dylib libB.dylib
```

An executable takes at most six guest images, the program itself counted. Each image is a pair of segments after
`__PAGEZERO`, `__TEXT` and `__DATA`, and dyld's bind and rebase opcodes name a segment with 4 bits: a writable segment past
index 15 would have its fixups written into another segment, and the program would die before `main`. `xlate` refuses
such an input when it translates, with the count, the limit and the way out: a library (`XL_LIBRARY=1`, see
[library mode](../../reference/recompiler/library-mode.md)) holds the guest as one image and has no limit of this kind.

`XL_FRAMEWORKS_DIR` finds a bundle's embedded frameworks. A bind takes an image by the install name it spells,
exactly: an app that binds the host's `NSString` next to an embedded image that defines its own keeps the host's. Two
images with one install name are an error.

A guest image that stands for a *system* library under another name has to say so, because nothing in the inputs
says it: `XL_REPLACES="/usr/lib/libc++.1.dylib=path/to/libc++.1.dylib ..."` (`xlate --replaces LIBRARY=IMAGE`). A
library named twice, or one that is an image's own install name, is refused. Without it the bind is the host's, and
xlate prints the `--replaces` line to use when an image's file name matches.

The Swift demo needs this. It binds `/usr/lib/libc++.1.dylib`, and the guest libc++ it runs on (built by
`revenant@libcxx`, with libswiftCore and libc++abi from `revenant@swift-runtime` built with `library_evolution=true`)
is `@rpath/libc++.1.dylib`, the recipe's name for it. It is translated with

```sh
XL_REPLACES=/usr/lib/libc++.1.dylib=<libs>/libc++.1.dylib \
  ./xmakew l -P . recompiler/tools/translate.lua <demo>-arm64 recompiler/include/swiftdemo-includes.h out/ \
  <libs>/libswiftCore.dylib <libs>/libc++.1.dylib <libs>/libc++abi.1.dylib
```

or the operators, guards and exception classes it takes from libc++ (307 names re-exported from libc++abi among them)
come from the host's C++ runtime instead of the guest's. The run takes about three and a half minutes; a module too
big for one object (more than `XL_OBJECT_BYTES` of bitcode, 6 MB by default) goes straight to the split into pieces of
that size, and the pieces are compiled four at a time (`XL_COMPILE_JOBS`). A run
whose guest images, bridge library and `xlate` are the last run's reuses its lifted objects and only recompiles and
relinks the runtime, a few seconds.

To get `<libs>`, build `revenant@swift-runtime` (`library_evolution=true`) and `revenant@libcxx` for `-p iphoneos -a arm64`
from a small project of your own (`add_requires` of the two, a phony target that uses them) with
`./xmakew f -P <project> -p iphoneos -a arm64 -y -c`, about four minutes, and link the dylibs of the two install
directories into one folder. That configure writes the *worktree's* `.xmake` (`apple_minimum 7.0`, the iphoneos
toolchain), and every `./xmakew l -P .` after it stops with `no target xlate: configure revenant for the host`:
`./xmakew f -P . -y -c` in the worktree gives the host configuration back.

The lifted code is compiled in Thumb-2 (`XL_LIFTED_MODE=thumb`, the default); `arm` compiles it in ARM mode, as it was
before. Any other value is refused. The mode is part of the key of the lifted objects, so changing it lifts and compiles
them again. The runtime, the crypto helpers and the bridge stay in ARM mode in every setting. LLVM's machine outliner is
not an option: with this LLVM it miscompiles the lifted code
([why](../../reference/recompiler/corpus.md#lifted-code-mode-thumb-2-and-the-outliner)).

`XL_REPORT_DUPLICATES=1` makes the lift print how many guest instructions it decoded in all and how many of them were
different, per kind of function and per image; what the lift does so that the two are close is described in
[what a lifted function is](../../explanation/recompiler/how-it-works.md#what-a-lifted-function-is). The setting is part
of the key of the lifted objects.

The lift rewrites the compare of Swift's extra-inhabitant test, which arm64 does with 4 GB, to the first page, because the
pointers of a translated program are below 4 GB ([extra inhabitants](../../reference/recompiler/extra-inhabitants.md)).
`XL_XI_THRESHOLD` sets the new value (default `0x1000`, `0` leaves the compares as they are) and `XL_XI_EXCEPT="Name ..."`
keeps the compares of the functions whose name contains one of the words, which a negative control needs. Every rewritten
compare is a line `xi-compare:` of `report.txt`; both settings are part of the key of the lifted objects.

A guest that uses a class which iOS 6.1.3 lacks (`NSURLComponents`, `NSURLQueryItem` and the other iOS 7+ classes the Foundation
overlay refers to) needs the Backports at translation: `BACKPORTS_DIR=<folder with lib*Backports.dylib>`
([how the Backports load](../../explanation/backports-loading.md)). Without it the class reference is weak and stays nil on the
phone, so `URLComponents(string:)` returns nil (measured on the iPhone 4S on 2026-11-14: `components.create` and
`components.items` fail without it and pass with it; `uncovered-classes.txt` of the translation lists the weak references).
The Backports that the app loads have to be built from a source in which the class adopts the protocols the Swift overlay
requires of it (`REVENANT_ALIAS_ADOPTS`, [the protocols of a class](../../explanation/backports-loading.md)): a
`libFoundationBackports.dylib` from before 2026-11-14 lets `URLComponents(string:)` work and then kills the process when the
value is released (signal 11, fault `0xfffffff0`), because `_MutableHandle<NSURLComponents>` cannot be instantiated.
A `libFoundationBackports.dylib` from before 2026-11-15 also leaves `JSONSerialization.data(withJSONObject:options: [.sortedKeys])` of a
translated library unsorted (measured on the iPhone 4S: 16 keys come back in hash order): the library binds to the proxy class of
`NSJSONSerialization`, and the wrapper that honours the option was set on the system class only
([wrappers of a system method](../../explanation/backports-loading.md)). With the fix the same fixture returns the keys in byte order.
A library translated since 2026-11-15 binds the classes the iOS 6 cache has (`NSJSONSerialization`, `NSMutableDictionary` and 20 more for the
reCAPTCHA Enterprise SDK) to the system library, and only the classes the cache lacks to the Backports; `system-classes.txt` and
`proxy-classes.txt` of the translation list both ([which class binds where](../../reference/recompiler/library-mode.md)).

## Translate a library

An arm64 dylib (and the guest images it needs) becomes an armv7 dylib that an app loads into its own process. See
[library mode](../../explanation/recompiler/library-mode.md) for why and for what the runtime does there.

```sh
XL_LIBRARY=1 ./xmakew l -P . recompiler/tools/translate.lua Lib.dylib includes.h out/ [guest images]
```

`includes.h` imports what the library uses and the library's own public header: a block parameter of a public method
has no signature in its type encoding, so the translator takes it from the header (without it the method is reported
`UNSUPPORTED: block parameter of a method the SDK does not declare` and traps when the host calls it). The output is
`out/<name>.dylib`, linked with its install name `@rpath/<name>.dylib` (`XL_INSTALL_NAME` changes it), and
`out/<name>-classes.dylib`, the registry of the Objective-C classes of the guest. Both files go to the app, into the same
folder; the registry depends on the library by the library's install name, which on iOS 6 must be a name dyld resolves
(`@executable_path/Frameworks/<name>.dylib`, or the folder in `DYLD_FALLBACK_LIBRARY_PATH` for an `@rpath` name).

- `XL_BASE` is the address where the loader maps the guest image (default `0x10000000`). Only the guest image
  (9.1 MB for the Swift library) is at a fixed address; the host part, the lifted code, is placed by dyld in any hole.
  The base has to be above the app's images and below the heap's random start; for Telegram13 that is `XL_BASE=0x18000000`
  ([the rule](../../reference/recompiler/library-mode.md#choosing-xl_base)). A host that holds the range gets
  `XL_LOAD_RANGE_BUSY` from `xl_reserve`, with the name of the holder.
- `XL_NAMESPACE` is the prefix of the Objective-C class names of every guest image but the first (default `XLG.`; `none`
  leaves the names). It keeps the guest's Swift runtime from taking the names of a Swift runtime the host has loaded; the
  guest still sees its own names. [What it changes](../../explanation/recompiler/library-mode.md).
- The library is stripped of its local symbols (`strip -x`) after it is linked; the symbol table the linker left, from
  `nm -n`, goes next to it as `out/<name>.symbols.txt`. The crash handler prints the image, its base and the offset of the
  faulting host address (`xlate: host pc in … image … base 0x… offset 0x…`), and the offset looked up in that file names the
  lifted function (`sub_<guest address>`). `XL_KEEP_LOCALS=1` keeps the symbols in the library.
- The app links `recompiler/src/loader/xl_loader.c` (headers `recompiler/include/xl_loader.h` and
  `recompiler/include/xl_guest_image.h`), reserves the guest range as early as it can, and loads the library when it first
  needs it:

```objc
xl_reserve(path);
...
if (xl_load(path) == XL_LOAD_OK) {
    Class client = NSClassFromString(@"RCFClient");
}
```

  `xl_load_error()` says why a load failed. The classes of the library are found by name only after `xl_load`
  succeeded; before that `NSClassFromString` answers `Nil`.
- `void *xl_find_class(const char *name)` returns the class of a name that the library answers to, or `NULL`. It finds
  what `NSClassFromString` finds and a Swift class by `"Module.Class"` (and its mangled name), which the host's own
  `NSClassFromString` does not on iOS 6 ([the contract](../../reference/recompiler/library-mode.md#the-class-of-a-name-xl_find_class-xl_library_class-objc_sethook_getclass)).
  Try `NSClassFromString`, then `xl_find_class`, when the name could be either.
- `xl_library_diagnostics()` (found with `dlsym`) installs the crash handlers and the exit note for a debugging session;
  an app that has its own crash reporter does not call it.

`./xmakew l -P . recompiler/tests/library/check.lua <out> [objc|swift]` builds a fixture library and a host app and runs
them on the claimed phone ([what it proves](../../reference/recompiler/corpus.md#library-device-part-by-hand)).

## Checks

- `./xmakew test -P . 'recompiler_corpus/*'` runs the host part of every corpus check.
- `./xmakew build -P . recompiler_cxxinit recompiler_refrepro recompiler_blockid recompiler_devtime` builds the corpus apps and the benchmark.
- `./xmakew l -P . recompiler/tests/<name>/check.lua <out>` runs a check whole, including its device part where it has
  one (weakimport, classpair, swiftconformance, swiftobjc).
- `./xmakew test -P . 'recompiler_*/*'` builds the translator and runs the host checks of its corpus together.

Run them before and after a translator change. [The corpus](../../reference/recompiler/corpus.md) says what each
check proves.
