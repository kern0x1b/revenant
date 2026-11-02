# Running Hermes bytecode on the iPhone 4S

The probe loads a Hermes bytecode file, runs it, and prints the time and memory of each step. It is built from `toolchain/tests/packages/hermes/probe.cpp` against `packages/h/hermes`, for armv7 iOS 6.0. The reference of the package is [the Hermes reference](../../reference/react-native/hermes.md).

## 1. Configure and install the package

Work in your own worktree, with its private cache (`docs/guides/machine.md`).

```sh
REVENANT_CACHE=$PWD/.cache-private ./xmakew f -P . -p iphoneos -a armv7 --component=packages -y
REVENANT_CACHE=$PWD/.cache-private ./xmakew require -P . -y revenant@hermes
```

The install builds the host `hermesc` first, then the armv7 archives. It takes about ten minutes on a cold cache.

## 2. Build the probe

```sh
REVENANT_CACHE=$PWD/.cache-private ./xmakew build -P . hermes_probe
```

The binary is `build/iphoneos/armv7/release/hermes_probe`.

## 3. Compile the bytecode

Compile with the `hermesc` of the same package, so that the bytecode version matches the engine. The host `hermesc` is in `build_host_hermesc/bin/` of the package's source tree in the private cache.

```sh
hermesc -O -emit-binary -out bench.hbc toolchain/tests/packages/hermes/bench.js
```

## 4. Stage the device folder

The probe needs the libc++ runtime beside it, and the executable needs a runpath for it and a signature:

```sh
mkdir -p stage/lib
cp build/iphoneos/armv7/release/hermes_probe bench.hbc stage/
cp LIBCXX_INSTALLDIR/lib/libc++.1.dylib LIBCXX_INSTALLDIR/lib/libc++abi.1.dylib stage/lib/
xcrun install_name_tool -add_rpath @executable_path/lib stage/hermes_probe
LDID_BINARY -S stage/hermes_probe
LDID_BINARY -S stage/lib/libc++.1.dylib
LDID_BINARY -S stage/lib/libc++abi.1.dylib
```

`LIBCXX_INSTALLDIR` is the installed `libcxx` package of the private cache, and `LDID_BINARY` is the `ldid` of the `ldid` package; both are under `.cache-private/xmake-global/.xmake/packages/`. The signature is applied after the runpath is added, because the runpath changes the binary.

## 5. Claim the phone and run

The device is one shared resource. Claim it under your own name, copy, run, and release it.

```sh
REVENANT_DEVICE_HOLDER=rn-hermes ./xmakew device --minutes=15 claim
REVENANT_DEVICE_HOLDER=rn-hermes ./xmakew l frameworks/SwiftUI/tools/device.lua copy stage/hermes_probe /var/tmp/hermes-probe/hermes_probe
REVENANT_DEVICE_HOLDER=rn-hermes ./xmakew l frameworks/SwiftUI/tools/device.lua copy stage/bench.hbc /var/tmp/hermes-probe/bench.hbc
REVENANT_DEVICE_HOLDER=rn-hermes ./xmakew l frameworks/SwiftUI/tools/device.lua copy stage/lib/libc++.1.dylib /var/tmp/hermes-probe/lib/libc++.1.dylib
REVENANT_DEVICE_HOLDER=rn-hermes ./xmakew l frameworks/SwiftUI/tools/device.lua copy stage/lib/libc++abi.1.dylib /var/tmp/hermes-probe/lib/libc++abi.1.dylib
REVENANT_DEVICE_HOLDER=rn-hermes ./xmakew device run 'chmod 755 /var/tmp/hermes-probe/hermes_probe; cd /var/tmp/hermes-probe; ./hermes_probe bench.hbc; echo EXIT=$?'
REVENANT_DEVICE_HOLDER=rn-hermes ./xmakew device release
```

The output has one `PROBE` line with the sizes and the timings, and one with the benchmark result. A crash prints `PROBE signal`, the faulting address and the frames, which map to the probe's symbols through the image slide the line also prints.

The probe ran as a command over ssh, not as an application. The phone locks about a minute after the last touch, and iOS suspends applications when it locks, so an application-based run needs the screen kept awake, as the RN host does with `idleTimerDisabled`.
