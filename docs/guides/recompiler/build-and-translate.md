# Build and translate

## Build

The recompiler is part of the revenant xmake project; run everything from the top of revenant. Every tool comes from
a package. LLVM 23 with its libraries comes from Revenant's `llvm` package (its `libraries` config), built from source
on the first configure. Rellume, farmdec and BlocksRuntime are packages of the package repository. The iOS SDK (for the
header-driven bridge generation), `ld64` and `ldid` are Revenant's packages. The first configure builds LLVM, which
took 40 to 75 minutes on the machine it was measured on.

```sh
./xmakew f -y
./xmakew build xlate xlgen
```

## Translate an executable

```sh
./xmakew l recompiler/tools/translate.lua path/to/app-arm64 includes.h out/
```

`includes.h` imports the frameworks the app uses. The output `out/<name>` is an armv7 iOS 6 executable; drop it into
the app bundle in place of the original.

A whole `.ipa` is translated with

```sh
./xmakew l recompiler/tools/ipa.lua App.ipa includes.h out/App.ipa
```

The translator takes a compiled arm64 Mach-O, never source. For an app under `targets/` that means the decrypted
executable and frameworks of its released `.ipa`, never objects built from an edited copy of its source. `tests/` and
`tests/perf/` build their own arm64 input from their own source.

## Guest libraries, and what a bind names

Further arguments are guest images lifted with the executable:

```sh
./xmakew l recompiler/tools/translate.lua app-arm64 includes.h out/ libA.dylib libB.dylib
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
  ./xmakew l recompiler/tools/translate.lua <demo>-arm64 recompiler/include/swiftdemo-includes.h out/ \
  <libs>/libswiftCore.dylib <libs>/libc++.1.dylib <libs>/libc++abi.1.dylib
```

or the operators, guards and exception classes it takes from libc++ (307 names re-exported from libc++abi among them)
come from the host's C++ runtime instead of the guest's. The run takes about three and a half minutes; a module too
big for one object goes straight to the split, and the pieces are compiled four at a time (`XL_COMPILE_JOBS`). A run
whose guest images, bridge library and `xlate` are the last run's reuses its lifted objects and only recompiles and
relinks the runtime, a few seconds.

## Checks

- `./xmakew test 'recompiler_corpus/*'` runs the host part of every corpus check.
- `./xmakew build recompiler_cxxinit recompiler_refrepro recompiler_blockid recompiler_devtime` builds the corpus apps and the benchmark.
- `./xmakew l recompiler/tests/<name>/check.lua <out>` runs a check whole, including its device part where it has
  one (weakimport, classpair, swiftconformance).
- `./xmakew test -P . 'recompiler_*/*'` builds the translator and runs the host checks of its corpus together.

Run them before and after a translator change. [The corpus](../../reference/recompiler/corpus.md) says what each
check proves.
