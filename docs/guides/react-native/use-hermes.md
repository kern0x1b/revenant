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

The host sources that select the engine are in `frameworks/ReactNative/src/host`: `RNHostRuntime` reads `engine=` and loads the bytecode, `RNHostAppDelegate` returns `RCTHermesInstance` from the runtime factory when the engine is Hermes, and `RNHostTouch` logs the time each injected touch begins. The package is declared at file scope (`add_requires("revenant@hermes", {alias = "hermes"})`) and used by the target (`add_packages("hermes")`); xmake drops a package name that is only used by the target without that declaration.

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

The JSC run with the manifest was not measured; the touch latency of both engines is in the benchmark below.

The memory numbers are one run per configuration; the first screen of the app with its workspace is the last row.

## Engine benchmark on the iPhone 4S

`frameworks/ReactNative/tests/bench` is a self-contained bench app: a 500-row list, a counter with `setState`, a looping animation, Promise and async chains, a JSON round trip, and an FPS log every second. `build.js` builds it with Metro (`node frameworks/ReactNative/tests/bench/build.js <work folder> <bundle.js> [default|hermes-stable]`); the Hermes bundle is `hermesc -O -emit-binary`. `./xmakew l -P . frameworks/ReactNative/tests/bench/measure.lua prepare BUNDLE_ID bundle.js bundle.hbc` copies the two bundles into the application folder of the host BUNDLE_ID, root-owned: the JavaScript bundle for JavaScriptCore and the Hermes bytecode of `hermesc`. `./xmakew l -P . frameworks/ReactNative/tests/bench/measure.lua run ENGINE RUN BUNDLE_ID [WAIT]` then runs one configuration on the claimed phone: it stops the host by its bundle id, selects the engine in the host's `rnhost.conf`, relaunches it, makes five taps on the counter and one swipe on the list, and writes the screenshot, the host log and the injector's answers to `.cache/scratch/rn-bench/runs/ENGINE-RUN`. `... measure.lua summarize RUNFOLDER...` prints the metrics of the runs. The taps go to the touch injector of the host (`RNHostTouch.m`, see [driving a host by touch](touch.md)); no `killall` is used, so other hosts on the phone keep running.

Three runs per engine, on the same host build (the HV64 package with the ToInt32 patch, `RN_HERMES=1`) and the same bench bundle, each after a fresh launch:

| Engine | Startup, react start to bench mounted | Tap to JS commit, median of 5 | fps, mean / lowest one-second window | RSS, highest heartbeat |
|---|---|---|---|---|
| Hermes, bytecode | 0.71, 0.74, 0.70 s | 163, 168, 168 ms | 59.2 / 20, 59.1 / 24, 59.2 / 21 | 59.2, 58.7, 58.7 MB |
| JSC, source | 2.57, 2.52, 2.42 s | 176, 169, 171 ms | 58.4 / 8, 58.3 / 6, 58.1 / 3 | 75.2, 75.9, 75.0 MB |

A fourth Hermes run made with `measure.lua` after the table (`hermes-9`) gave 0.73 s startup, a 164 ms median and 59.0 / 19 fps.

- The tap latency runs from the injected touch (`rn-host: touch began`, epoch milliseconds) to the `bench commit` log, which is written in the effect after the count update commits. It does not include the paint.
- The startup is read from the syslog timestamps of the two lines.
- The lowest fps window of each run includes the swipe; the mean covers the whole run.
- One Hermes launch, made right after `killall` of the previous instance, aborted in `startSurface` before the bench mounted (`Global was not installed`); the next launch of the same configuration ran cleanly, and none of the six measured runs had that abort. The cause is not identified.
- `frameworks/ReactNative/tools/touch.lua`, the tool for a single manual touch, is in this branch; its contract is in [driving a host by touch](touch.md).
