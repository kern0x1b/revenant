# Hermes as a React Native engine on iOS 6

React Native 0.86.3 runs JavaScriptCore by default. This guide covers Hermes beside it: the package, the host build that selects it, the bytecode bundle, and what was measured on an iPhone 4S (iOS 6.1.3, armv7). The probe alone is in `hermes-probe.md`.

## What is selected where

- The package is `packages/h/hermes`, Hermes 250829098.0.17, the line React Native 0.86.3 ships. Its `hermesvm` is linked; JSI is react-native's own, which the host already links.
- The host build selects Hermes with `RN_HERMES=1`. It adds `RCTHermesInstance` and `HermesInstance`, the runtime factory React Native's bridgeless path uses, and the inspector chrome sources the target delegate needs.
- The engine of a run is the `engine=` key of the host's configuration file: `engine=hermes` or `engine=jsc`. Both engines are in one binary, so the switch is at run time; the build flag only decides whether Hermes is linked.
- The bundle is Hermes bytecode made by the `hermesc` of the same package (`build_host_hermesc/bin/hermesc`), so the bytecode version matches the engine. JavaScriptCore reads the source bundle.

## Build

```sh
REVENANT_CACHE=$PWD/.cache-private ./xmakew f -P . -p iphoneos -a armv7 --component=packages -y
REVENANT_CACHE=$PWD/.cache-private ./xmakew require -P . -y revenant@hermes
RN_HERMES=1 REVENANT_CACHE=$PWD/.cache-private ./xmakew l -P . frameworks/ReactNative/tools/isolate.lua build <folder> --cache $PWD/.cache-private --target RNHost --log <file>
```

`isolate.lua build` links the copy's `build/rn-src` to the react-native install of the cache on every run. A link left to an install that xmake replaced dangles, and the build then fails on the React Native headers (the archive step reports `ar: no archive members specified`).

The host sources that select the engine (`RCTHermesInstance` in the runtime factory, the `engine=` reader and the bytecode loader) are in the isolated host spike, not yet in this tree.

## Bytecode

```sh
hermesc -O -emit-binary -out bundle.hbc bundle.js
```

The magic of a Hermes bytecode file is `c6 1f bc 03 c1 03 19 1f`. The host reads the bytecode in place, without a copy.

## Promise and HermesInternal

React Native keeps the engine's own `Promise` only when `HermesInternal.hasPromise()` says the engine provides one; otherwise it installs its polyfill. Measured on the device with a small bytecode check bundle, run through the direct JSI path (bytecode version 98):

- `Promise === globalThis.Promise`: true
- an async function returns an instance of `Promise`: true
- `typeof HermesInternal`: `object`; `HermesInternal.hasPromise()`: true, so the engine's Promise is kept

The bridgeless path of the full app was not checked directly; it reads the same flag.

## Measured on the iPhone 4S

All runs use the 24 MB application bundle. The Hermes run uses the bytecode of 31.87 MB.

| Run | Engine | Start to "Running main" | RSS |
|---|---|---|---|
| No manifest, error boundary | JSC, source 24.66 MB | 9.73 s | 127 MB steady |
| No manifest, error boundary | Hermes PREFER32, bytecode | 1.38 s | 75 MB steady |
| No manifest, error boundary | Hermes HV64, bytecode | about 2.1 s after react start | 77 MB steady |
| With the app manifest, first screen | Hermes HV64, bytecode | about 1 s | 109 MB, then 142 MB |
| With the app manifest and the stored workspace state | Hermes HV64, bytecode | about 1 s | 113 MB, then 169 MB in 25 s |

The JSC run with the manifest and the touch latency of both engines were not measured.

The memory numbers are one run per configuration; the first screen of the app with its workspace is the last row.
