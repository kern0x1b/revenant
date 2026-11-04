# JavaScriptCore bytecode cache for the React Native host

This page is the state of the bytecode cache on the JavaScriptCore host: what the engine exports, how the host reaches it,
and what has not been measured. The cold and warm times on the Paseo bundle are not measured yet, so the comparison with the
8.5 s of the plain evaluate and the 0.75 s of Hermes is still open.

## The engine

The engine is the prebuilt `webkit-engine` `fe668b538a34b49e5d7fd9f875262a7c` from the `kern0x1b/revenant` release
`prebuilt-webkit-engine-fe668b538a34b49e5d7fd9f875262a7c`. Its asset is `webkit-engine-fe668b538a34b49e5d7fd9f875262a7c-iphoneos-armv7.tar.xz`,
38,561,572 bytes, and its `.sha256` matches the download.

The tarball lays the engine out as `batteries/Frameworks/JavaScriptCore.framework/JavaScriptCore` (43,682,464 bytes), with
`batteries/jsc`, `batteries/Frameworks/libc++*.dylib`, `stage/usr/lib` and `licenses/`. The `rn-jsc-engine` package of the
host's `xmake.lua` takes the folder named by `RN_JSC_ENGINE` and copies its `bundle/` subfolder, so the engine has to sit in a
folder with a `bundle/Frameworks/` inside. The layout the coordinator named, `<engine>/bundle/frameworks`, is not what the
tarball contains: the folder is `batteries/`, and it has to be renamed or linked as `bundle` for the package to find it.

## The API the engine exports

The engine's binary has the JavaScript source API and the bytecode cache from upstream JavaScriptCore:

| Layer | Symbol or selector | Present |
| --- | --- | --- |
| C | `_JSScriptCreateFromString`, `_JSScriptCreateReferencingImmortalASCIIText`, `_JSScriptEvaluate`, `_JSScriptRetain`, `_JSScriptRelease` | yes |
| Objective-C class | `_OBJC_CLASS_$_JSScript`, `_OBJC_CLASS_$_JSContext` | yes |
| `JSScript` | `scriptOfType:withSource:andSourceURL:andBytecodeCache:inVirtualMachine:error:` | yes |
| `JSScript` | `scriptOfType:memoryMappedFromASCIIFile:withSourceURL:andBytecodeCache:inVirtualMachine:error:` | yes |
| `JSScript` | `cacheBytecodeWithError:`, `isUsingBytecodeCache` | yes |
| `JSContext` | `contextWithJSGlobalContextRef:`, `virtualMachine`, `evaluateJSScript:`, `exception` | yes |
| C++ | `JSC::encodeCodeBlock` (with a file handle and `BytecodeCacheError`), `JSC::generateProgramBytecode`, `JSC::computeJSCBytecodeCacheVersion` | yes |
| C++ | `JSC::CachedBytecode::addGlobalUpdate`, `addFunctionUpdate`, `JSC::CachePayload::makeMappedPayload`, `makeMallocPayload` | yes |

The engine's `JSC_*` option strings list only the iOS 6 collector options (`JSC_IOS6_GC_*`, `JSC_IOS6_SWEEP_*`), the profiler
path and the GC signal; the tier-up thresholds are read by name from the environment and are not listed as strings.

The patches that the DFG page depends on are in the binary too: `JSC::Ios6BlockReservationPool` (patch 0005) and
`JSC::ARMv7Assembler::linkJumpT4` (patch 0006). So the DFG diagnostics named in the coordinator's brief could be run on this
engine, but adding assertions to it needs a rebuild, and that is not done.

## How the host reaches the context

The host creates its runtime with `facebook::jsc::makeJSCRuntime()`. In the react-native 0.86.3 sources, `JSCRuntime.cpp`
keeps the last `JSGlobalContextRef` it created and returns it from `RNJscRuntimeContext()`, an `extern "C"` function. Its
`evaluateJavaScript` calls `JSEvaluateScript` on that same context and has no cache.

So a cache path can use the runtime's own global object, where the host functions are installed:

1. take `RNJscRuntimeContext()`;
2. wrap it with `[JSContext contextWithJSGlobalContextRef:]`;
3. create the script with `scriptOfType:withSource:andSourceURL:andBytecodeCache:inVirtualMachine:error:`, with the cache URL;
4. run it with `evaluateJSScript:` and, on a cold run, call `cacheBytecodeWithError:` after the evaluate.

The host's `RNHostRuntime.mm` has no such branch in the repository. A branch of this shape was written in an isolated copy of
the host, under `.cache-private/scratch/rn-jsc-perf/host/`, and the copy's configuration allowlist was given the key
`bytecode`. Neither change is committed. The copy was not built: see below.

## What is not measured

- The cold and warm `evaluate` times on the Paseo bundle, and the 8.5 s and 0.75 s they should be compared with.
- The size of the cache file, and the time `cacheBytecodeWithError:` takes after a cold run.
- Whether the cache written after the evaluate holds the functions that were compiled lazily during `main`, or only the
  top-level code. The API suggests function updates, but the file's contents were not inspected.
- The resident memory with the cache. The phone has 512 MB, and the bundle's 24 MB source is held by an `NSString` and by
  the engine's copy while the script is created.
- Whether `isUsingBytecodeCache` is true on the second launch.
- Whether a cache from another engine build is rejected by the version check (`computeJSCBytecodeCacheVersion`).
- The DFG reproduction on this engine. It needs the host build below.

## Why the host build did not finish

The isolated copy was made by `isolate.lua copy` with the bundle id `org.revenant.rnhost.rn-jsc-perf` (23 files rewritten, 905
links retargeted). The first `isolate.lua build` stopped in configuration at `install swift-runtime 6.4.0` with "there is no
shared cache or library folder at `.cache-private/dyld/6.0/dyld_shared_cache_armv7`". Linking the private cache's `dyld` to
the main checkout's `.cache/dyld` fixed that step, and the restarted configuration got past swift-runtime, OpenCombine,
swift-crypto, swiftui, cryptokit and uniformtypeidentifiers. The coordinator then stopped the builds, and the restart was
killed with SIGTERM (exit 143) before it produced an app. No `.app` exists.

## Risk to settle before a cache ships

A bytecode cache file that the host loads is executed code. On iOS 6 every app runs as the `mobile` user, so a file in
`/var/tmp` that any app can write would let that app run code in the host. The host reads its configuration and bundle
only from its own root-owned `.app`; a cache in `/var/tmp/rn-jsc-perf/` would break that rule. A shipped cache has to be
written where only the host can write it, and it has to be checked against a digest of the bundle before it is loaded.
The measurement may use `/var/tmp`, but nothing that depends on it may ship with it.

## Next steps

1. With the coordinator's word, rebuild the isolated host with `RN_JSC_ENGINE` pointing at a folder whose `bundle/` is the
   engine tarball's `batteries/`, and deploy it under `org.revenant.rnhost.rn-jsc-perf`.
2. Run three evaluates on the phone: no cache (the existing JSI path, for the baseline), a cold run with the cache written,
   and a warm run that loads it. Record the `rn-host: bytecode:` lines and the `evaluated in` times.
3. Repeat the DFG reproduction on the same host with `JSC_useDFGJIT=true` and the lowered thresholds, to see whether the
   prebuilt engine faults as the earlier engine did.
