# Write and install the Backports package

`org.revenant.backports` holds every Backports library of the checkout, and the Swift runtime and libc++ packages it names in `Depends`. It is written by the root project only, and the root project has to be configured as a whole for iPhoneOS armv7: the package carries WebKit's engine (`WebKitBackports` names it, so the writer needs `WebKitEngine`), and `swift-runtime` and `libcxx` are required only by that configuration. A configuration with `--component=Backports` builds every library but cannot write the package, because it has no `WebKitEngine` target to hold the engine.

Run every command from the top of the checkout. In a linked worktree first make its private cache as [the machine guide](../machine.md#a-private-cache) says, and set `REVENANT_CACHE` to that folder for each command below.

## Sequence

```sh
./xmakew f -P . -c -p iphoneos -a armv7 -y     # the whole project; -c clears a component an earlier configure left stored
./xmakew show -P .                             # plat: iphoneos and arch: armv7
./xmakew deb -P .                              # writes the packages under build/: org.revenant.backports and the Swift runtime
ls build/*.deb                                 # the file names the writer printed, one per package
```

To install on the phone that `device.env` names, copy each package and run `dpkg -i`. `./xmakew device install -P .` does the same
for every package the root project writes, which includes the test probes and the tweaks, so it is not the way to install only the
Backports package:

```sh
export REVENANT_DEVICE_HOLDER=<name>           # every device command checks the claim against this name
./xmakew device --minutes=30 claim
./xmakew l frameworks/SwiftUI/tools/device.lua copy build/<package>.deb /tmp/<package>.deb
./xmakew device run "dpkg -i /tmp/<package>.deb && rm -f /tmp/<package>.deb"
./xmakew device run "dpkg -l | grep revenant"  # the version the package now has
./xmakew device release
```

Install the Swift runtime package before `org.revenant.backports`, since the latter `Depends` on it at its exact version.

## What not to run

- `./xmakew deb -P packages/b/backports` and `./xmakew device install -P packages/b/backports` do not work: the recipe folder is not
  an xmake project, so `device` and `deb` are not tasks there (`invalid task: device`). The package is written by `-P .`.
- Do not configure with `--component=Backports` and then run `deb -P .`: the writer stops at `WebKitBackports` with "the project has no
  WebKitEngine target to hold it". A configure keeps the options of the one before it, so `-c` is what clears a stored `--component`.

## Status

The probes of `frameworks/Backports/tests/device_probe` link (`BackportsDeviceProbe` and the others that compile `src/Metal` or
`src/MetalPerformanceShaders` into their own executable), and the component configure and build run. The whole configure above does
not finish on this machine yet: it needs the `libsql` package, which builds the Rust nightly its recipe names, and the `swift-runtime`
and `webkit-engine` packages at the keys of the whole configuration, for which no prebuilt release exists. Until those build, `deb -P .`
cannot write the package, and the sequence above is what the writer runs, not a result that has been run to its end.
