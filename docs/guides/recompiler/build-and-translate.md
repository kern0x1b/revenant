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

## Translate a library

An arm64 dylib (and the guest images it needs) becomes an armv7 dylib that an app loads into its own process. See
[library mode](../../explanation/recompiler/library-mode.md) for why and for what the runtime does there.

```sh
XL_LIBRARY=1 ./xmakew l -P . recompiler/tools/translate.lua Lib.dylib includes.h out/ [guest images]
```

`includes.h` imports what the library uses and the library's own public header: a block parameter of a public method
has no signature in its type encoding, so the translator takes it from the header (without it the method is reported
`UNSUPPORTED: block parameter of a method the SDK does not declare` and traps when the host calls it). The output is
`out/<name>.dylib`, linked with its install name `@rpath/<name>.dylib` (`XL_INSTALL_NAME` changes it).

- `XL_BASE` is the address of the guest window (default `0x10000000`). The lifted code sits just below it, in a window
  of the size of the lifted code plus 8 MB, rounded up to 16 MB, so the library occupies `XL_BASE` minus that window up
  to the end of the guest segments. An app whose images or heap hold that range needs another `XL_BASE`; ld64 links an
  armv7 dylib with guest segments only below about `0x40000000`. The translation stops with a message naming
  `XL_BASE` when the window is larger than the base itself.
- The app links `recompiler/src/loader/xl_loader.c` (header `recompiler/include/xl_loader.h`), reserves the range as
  early as it can, and loads the library when it first needs it:

```objc
xl_reserve(path);
...
if (xl_load(path) == XL_LOAD_OK) {
    Class client = NSClassFromString(@"RCFClient");
}
```

  `xl_load_error()` says why a load failed. The classes of the library are found by name only after `xl_load`
  succeeded; before that `NSClassFromString` answers `Nil`.
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
