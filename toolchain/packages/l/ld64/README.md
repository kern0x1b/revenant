# ld64 (cctools-port, ld64-956.6)

Apple's ld64 from `tpoechtrager/cctools-port`, pinned at `904de2a7` (the `1030.6.3-ld64-956.6` branch tip),
built from source with three patches in `patches/`. It exists because the system `/usr/bin/ld` does not
insert armv7 branch islands, and because `on_fetch` refuses the system linker outright: a toolchain
package is otherwise looked for on the system first, a clean store finds Apple's `ld` under this name and
never builds ours.

`toolchains/apple-ios/xmake.lua` puts this package's `bin/ld` in `-fuse-ld=` for every armv7 device link
a port does, so this is the linker the whole fleet links with.

## The patches

| patch | why |
| --- | --- |
| `libtapi-without-darwin-linker-version-helper.patch` | libtapi builds against a host without `ld`'s linker-version helper |
| `inlined-text-stub-before-search-paths.patch` | use the TAPI file inlined in a `.tbd` before searching the paths |
| `ordinal-for-dylib-that-only-a-reexport-reaches.patch` | the defect below |
| `link-snapshot-beside-the-output.patch` | an assertion's link snapshot goes beside the output, not into `/tmp` |

## Where an assertion's link snapshot lands

`ld64`'s own options do not give what is wanted here, which is why this is a patch:

- `-snapshot_dir <path>` sets the directory, but it also calls `setSnapshotMode(SNAPSHOT_DEBUG)` and
  `fSnapshotRequested = true` (`Options.cpp:4013-4018`), so it *turns the snapshot on* for a link that
  would otherwise write nothing. It is the opposite of a way to keep the snapshot and move it.
- The one environment route is `LD_TRACE_FILE`: `Snapshot::createSnapshot` uses the *directory* of it
  (`Snapshot.cpp:243`, rdar://89496214), and that is Apple's build system's, not ours to set.
- Nothing switches off the one an assertion writes. `ld64`'s `__assert_rtn` (`ld.cpp:1708`, the assert
  override) calls `setSnapshotMode(SNAPSHOT_DEBUG)` and `createSnapshot()` itself. The only way it stays
  off today is the directory not being creatable, at which point `createSnapshot` falls back to
  `SNAPSHOT_DISABLED` with a warning (`Snapshot.cpp:261`).

So the default location moves instead: beside the output the snapshot describes, which is what `-o`
names, and the current directory when there is no `-o` (the output is then `a.out`). Measured, on the same
assertion, with the ordinal code unpatched so the link still aborts:

```
unpatched:  A linker snapshot was created at:  /tmp/a.dylib-2026-09-28-130757.ld-snapshot
patched:    A linker snapshot was created at:  .../snapmeasure/b.dylib-2026-09-28-130757.ld-snapshot
```

`ls /tmp | grep -c ld-snapshot` goes 0 -> 1 on the first and stays 1 on the second, so the patched linker
adds nothing to `/tmp`; the snapshot is 171 MB, which is why it matters that it is somewhere a build can
clean up. A *successful* link writes no snapshot either way: `createSnapshot` is reached on the non-assert
path only when `fSnapshotRequested` is set, which this recipe never does.


## The dylibToOrdinal defect, and what it is

`ld/OutputFile.cpp:5219` `buildDylibOrdinalMapping` gives an ordinal to every dylib in `state.dylibs` and
to every synthetic dylib it makes for a `$ld$previous$` install, and to nothing else. `dylibToOrdinal`
(5211) then asserts when an import proxy asks for a dylib that has no ordinal, and `compressedOrdinalForAtom`
(5344) asserts on the same missing entry. Both are reached from the symbol-table and bind encoders.

The dylib that misses is measured, not guessed: an instrumented build of this same tree, which prints the
dylib and the symbol instead of asserting, names

```
no ordinal for dylib leaf=libobjc.tbd
  path=…/iPhoneOS16.4.sdk/usr/lib/libobjc.tbd
  install=/usr/lib/libobjc.A.dylib  implicit=1 explicit=0 provided=1
```

and the symbols `_objc_getClass`, `_class_getSuperclass`, `_object_getClass`, `_objc_getAssociatedObject`,
`_objc_setAssociatedObject`. `state.dylibs` is filled from two lists, and `libobjc.tbd` is in neither:

- `_inputFiles` (`InputFiles.cpp:1568-1574`), which holds only the files named on the command line —
  `_inputFiles.push_back(makeFile(*entry, false))` at `:1053`, plus opaque sections and NULLs. A dylib
  reached only through another one is made by `findDylib` through `makeFile(info, true)` (`:648`) and
  registered with `addDylib` (`:653`), and never lands on `_inputFiles`. `libobjc.tbd` is never named on
  the link line, so it is not there.
- the implicitly linked entries of `_installPathToDylibs` (`InputFiles.cpp:1582-1607`). The
  instrumentation says `implicit=1`, so this loop *would* add it — were it the file the map holds for
  its install name. It is not: `addDylib` inserts into the map only when the path is absent
  (`:1205-1208`), and `/usr/lib/libobjc.A.dylib` is already held by `libobjc.A.tbd`, which is the `File`
  that holds ordinal 6.

So the dylib that owns those proxies was never named on the command line, and is not the file the map
holds for its install path. It gets no ordinal, and encoding its proxy aborts.

The patch repairs the invariant where the encoder needs it: after the ordinal loop, sweep the
import-proxies sections and give such a dylib the ordinal of the dylib already loaded under its install
path (`hasOrdinalForInstallPath`), or a fresh one plus an `_dylibsToLoad` entry so the library the symbol
came from is the one the output loads and binds to. Nothing that linked before changes — measured, not
argued: the 123-object Matter link with `-Wl,-no_implicit_dylibs`, which already worked, comes out
**byte-identical** (`shasum -a 256` `307de01e2d2a454cceb1e4e25a15a1d2a73e114a86dd1b5ea0b3530c38f10d5f`)
from the unpatched and the patched linker, when both write the same output path. Without that flag the
same link aborts unpatched and links patched.

## Reproducing it

The smallest link that aborts, reduced by ddmin from the 123-object `libMatterBackports.dylib` link:

```
clang -target armv7-apple-ios -miphoneos-version-min=6.1.3 -isysroot <iPhoneOS16.4.sdk> -mlinker-version=956.6 \
  -fuse-ld=<ld> -dynamiclib -install_name /usr/lib/charon/org.charon.apple-backports/libMatterBackports.dylib \
  -o out.dylib libCHIP.a src/app/clusters/descriptor/DescriptorCluster.cpp.o \
  -L<libcxx>/lib -lc++ libapple-compat.a -framework Foundation -framework CoreBluetooth
```

one object, no `-lc++abi`, no backports, no `-no_implicit_dylibs`. It aborts in
`compressedOrdinalForAtom`; the full 123-object link aborts in `dylibToOrdinal`, the same missing ordinal.

## The store, and why a rebuild of this package is a fleet event

This recipe **had** no digest: `add_versions("956.6", "6809ba18…")` was a fixed string and nothing hashed
`patches/`, unlike `packages/a/apple-backports/xmake.lua`, which puts a `sources` config hashed from its
own files into the package identity. So a patch added here did not change the install path
`~/.xmake/packages/l/ld64/956.6/aac8ea2d04874dfdbdc0b81f5db2dd03/`, and the fix was invisible until that
directory was rebuilt — and because `toolchains/apple-ios` hands this `ld` to every armv7 link, whoever
rebuilt it changed the linker for every package in the fleet at once. It now carries the digest over
`patches/` described below, and the store shows the two apart:
`aac8ea2d04874dfdbdc0b81f5db2dd03` (Sep 16) and `a5083ad21d0544179849329a215a04e3` (Sep 28), the same
version string beside a second install path, with the old one still working.

`ld64` also has exactly one in-tree dependent, `packages/i/iphoneos-sdk`, which uses it for four `-r`
relocations of `crt1.o`, `crt1.3.1.o`, `dylib1.o` and `bundle1.o`. Everything else reaches it through the
toolchain.

## What the `-Wl,-no_implicit_dylibs` workaround actually produced

It linked, and it was wrong in a way nothing in the band reported. On the reduced reproducer:

```
before (workaround):  _objc_getClass (from Foundation)   _class_getSuperclass (from Foundation)
after  (fix):         _objc_getClass (from libobjc)      _class_getSuperclass (from libobjc)
```

`llvm-otool -L` counts 5 load commands for the workaround's dylib and 7 for the fix's; the two the fix adds
are `/usr/lib/libobjc.A.dylib` and CoreFoundation. With implicit dylibs off there is no ordinal for the
`File` that actually exports the ObjC runtime, so the symbols were bound to a library that does not export
them — a link that succeeds and a binary that binds wrongly on the device. The flag is no longer on any
recipe: `packages/m/matter/xmake.lua`, the one place that carried it, drops it, because the linker that
needed the workaround is the one this series fixes.

## The digest over patches/

`add_configs("patches", ...)` hashes this package's `patches/*.patch` into the package identity, the shape
`packages/a/apple-backports/xmake.lua` uses for its own sources. The reason is the same as the fix's: this
is the linker every armv7 link in the fleet uses, so a rebuild in place changes the linker under every
package at once, and a patch edited here was invisible until somebody happened to rebuild. With the digest,
a changed linker is a different package that installs beside the old one and the old install path keeps
working.

The consequence to expect: the first build after this lands installs a **new** `ld64` installdir, and every
package that depends on it re-resolves onto that one. That is a fleet-wide rebuild of the linked packages,
coordinated rather than accidental.
