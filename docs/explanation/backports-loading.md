# Loading the backports

How a symbol that iOS 6 lacks resolves to a backports library, and which option keeps one `.deb` correct on iOS 6, 7 and later. Each claim is marked as read in source (dyld-210.2.3 and objc4 master, through a summarising fetch and not checked against a local clone), read in this repository, or to measure on a device. Nothing here was built or run on a device.

## The mechanism

- **Binding.** A two-level import names one library by ordinal, and the lookup stays inside that image and what it re-exports (`ImageLoaderMachOCompressed::resolveTwolevel`, read in dyld-210.2.3). A missing weak import binds to 0. A missing non-weak import calls `throwSymbolNotFound`: for a non-lazy pointer the process dies while binding, for a lazy one at the first call (the lazy case is to measure). A missing dependent dylib follows the same split. Only a flat-namespace import searches every loaded image (`resolveFlat`). An image that is merely loaded cannot satisfy an import that names another library.
- **Classes.** A backported class is a proxy `RevenantX`. Its symbol `_OBJC_CLASS_$_X` is an alias of the proxy's (`toolchain/packages/frameworks/apple-backports/revenant_alias.h`, `REVENANT_ALIAS_LINKAGE`). The proxy forwards to `objc_getClass("X")` when the system has X, and `attach.c` reparents it to the system class at load. The runtime sees only `RevenantX`, so no two classes share a name.
- **Bands.** `toolchain/modules/apple/backports.lua` builds one library per release range. `band()` (line 674) keeps what the release lacks and re-exports the rest through a stub whose install name is the real framework (`stubs()`, line 798). `link()` gives a framework its real install path only where the release has it (lines 1025-1036).
- **Consumers.** Native apps link the libraries the package provides (`toolchain/modules/apple/platform.lua:137`). Recompiled apps are relinked against `BACKPORTS_DIR` with `-Wl,-dead_strip_dylibs` (`recompiler/tools/translate.lua:357-363`, `:519`).
- **Gaps.** The real-path install of an absent framework (Metal in `platform.md`) is not built. The C and Swift stubs are weak definitions bound by name, and whether the system's definition wins is not measured (`frameworks/Backports/README.md`). `frameworks/Backports/src/` does not exist yet, so the alias and attach files have not moved.

## Options

| Option | Recompiled apps | Native apps | Memory (512 MB) | Risk | Effort |
|---|---|---|---|---|---|
| (a) patched dyld | yes | yes | nothing extra per process | very high: the loader of every process; a bad build does not boot | high, one per release |
| (b) modified shared cache | yes | yes | the cache grows; its pages are shared | high: regenerated on OS update; a bad cache fails boot | high |
| (c) re-export wrappers (built) | yes, by relink | yes, by `add_deps` | only processes that link one; native dead strip unmeasured | low; one band per release, so one `.deb` needs runtime deferral | low; built; real-path install not built |
| (d) `DYLD_INSERT_LIBRARIES` or a Substrate filter, add-image callbacks, rebinding | only if it reaches the process | only if not restricted | every process unless filtered | high: the variable is pruned for restricted binaries; it cannot change a two-level bind; rebinding happens after bind | medium |
| (e) recompiler binds at translation (built) | yes, the best place | n/a | best: dead strip keeps only used dylibs | low to medium: link order; `-U` class gaps | low; mostly there |
| (f) (c) and (e) with runtime deferral: alias for ObjC, forwarder for C and Swift | yes | yes | per process; one forwarding call | medium: a call per forwarded symbol; the C path is unbuilt | medium |

## Answers

1. **iOS 6 binding.** A missing non-weak symbol kills the app at bind, or at first call for a lazy pointer; a missing weak one binds to 0.
2. **Options.** (a) and (b) change what every process maps, for one fix. (d) cannot resolve a two-level import, because injection does not change the named library, and an injected constructor runs after the app's binds (to measure). The `-U` lookups in `translate.lua` appear to become flat binds; verify with `otool -rv` on a built binary.
3. **ObjC.** At compile time, `_OBJC_CLASS_$_X` in the wrapper aliases `_OBJC_CLASS_$_RevenantX`, so the ordinal bind finds it. At run time, the proxy's `class`, `alloc`, `superclass` and related methods are decided per call by `objc_getClass`. Runtime registration alone cannot work: a bind needs a symbol, and an `objc_allocateClassPair` class has none. Registering X directly makes a second X. objc4's `addNamedClass` keeps the first class in the name table and reports the duplicate (`inform_duplicate`, read in objc4 master; the iOS 6 objc4-532 source was not fetched). The alias has a cost: an inherited class method runs with the proxy as `self` on iOS 7 and later, so `self == [X class]` needs the macro's help.
4. **Memory.** A process pays only if it loads a wrapper, because the wrapper's constructor registers its classes and methods. Recompiled apps keep only the dylibs they use. Native apps may load every library the package provides (`provided_libraries`, `platform.lua:211`), to measure. (a) and (b) cost nothing per process unless something is linked, but (d) loads into every process unless filtered.
5. **One `.deb`, iOS 6 to later.** Only a choice made at run time works across releases. ObjC already does this. By the lookup rule in item 1, a C or Swift symbol that the band carries shadows the system's on iOS 7 and later (to measure: item 4 below). So the forwarder must use the system's definition when it exists, looked up in the system image's handle (`dlsym`), not `RTLD_DEFAULT`, which would find the wrapper again. Real-path installs cannot be part of the package: on iOS 7 and later the real framework exists, and the package would overwrite it.

## Recommendation

Take (f), built from (c) and (e). Keep the wrappers in `/usr/lib/revenant/org.revenant.apple-backports/`, chosen by ordinal at link time for native and recompiled apps. Make every wrapper defer at run time: ObjC through the existing alias, C and Swift through a forwarder that uses the system's symbol when the system has it. Keep real-path installs out of the package, and let the load command name the wrapper instead; measure whether anything still names the real path. Reject (a) and (b) as too risky for one package. Keep (d) for diagnosis only.

## To measure on a device

1. The dyld build on iOS 6.1.3: `strings -a` on the dyld binary of the release under `~/.revenant/dyld/<release>/`, for `dyld-`. This settles whether dyld-210.2.3 is the reference.
2. Missing-symbol timing: an app with a non-weak import the wrapper lacks. Does it die at launch or at first call, and what does syslog say? Then the `weak_import` variant: is the pointer NULL?
3. Native load set: `otool -L` on a built app against the count of `lib*Backports.dylib` in `linkdirs`. Then `_dyld_image_count()` and resident size from `task_info` with zero and one wrapper linked.
4. C shadowing on iOS 7 or later: call a backported C function and `dladdr` its address. The image path says which implementation ran.
5. Injection: a library whose constructor writes a file, inserted into a store-signed app on 6.1.3. Does the file appear, and before or after the app's first bind?
6. Real-path load: `otool -L` on a translated binary built with `-weak_framework Metal`. Is a `Metal.framework` load command left?
