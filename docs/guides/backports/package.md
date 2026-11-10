# Write and install the Backports package

`org.revenant.backports` holds every Backports library of the checkout. It is written by the root project only, and the root project has to be configured as a whole for iPhoneOS armv7: the package carries WebKit's engine (`WebKitBackports` names it, so the writer needs `WebKitEngine`), which it names in `Depends` together with the libc++ package that engine needs. The Backports libraries themselves do not link the Swift runtime, so `org.revenant.swift-runtime-*` is not in its `Depends`. A configuration with `--component=Backports` builds every library but cannot write the package, because it has no `WebKitEngine` target to hold the engine.

Run every command from the top of the checkout. In a linked worktree first make its private cache as [the machine guide](../machine.md#a-private-cache) says, and set `REVENANT_CACHE` to that folder for each command below.

## Sequence

```sh
./xmakew f -P . -c -p iphoneos -a armv7 -y     # the whole project; -c clears a component an earlier configure left stored
./xmakew show -P .                             # plat: iphoneos and arch: armv7
./xmakew deb -P .                              # writes the packages under build/: org.revenant.backports and the Swift runtime
ls build/*.deb                                 # the file names the writer printed, one per package
```

To install on the phone that `device.env` names, copy each package and run `dpkg` on the phone. `./xmakew device install -P .` does the
same for every package the root project writes, which includes the test probes and the tweaks, so it is not the way to install only the
Backports package. Set the claim holder for the shell first, then claim the phone:

```sh
export REVENANT_DEVICE_HOLDER=<name>
./xmakew device -P . --minutes=30 claim
./xmakew l -P . frameworks/SwiftUI/tools/device.lua copy build/<package>.deb /tmp/<package>.deb
./xmakew device -P . run "dpkg --install /tmp/<package>.deb && rm --force /tmp/<package>.deb"
./xmakew device -P . release
```

The version the phone now has is the one `dpkg -l | grep revenant` lists, run on the phone through `device run` with the same claim.
Install the packages a package `Depends` on before it, at the exact versions `dpkg-deb -f build/<package>.deb Depends` prints: the libc++
package, then `org.revenant.webkit-engine-*`, then `org.revenant.backports`. `dpkg --install` does not fetch them, so a missing one leaves
the package unconfigured.

## What not to run

- `deb` and `device install` with `-P packages/b/backports` do not work: the recipe folder is not an xmake project, so `device` and
  `deb` are not tasks there (`invalid task: device`). The package is written by `-P .`.
- Do not configure with `--component=Backports` and then run `deb -P .`: the writer stops at `WebKitBackports` with "the project has no
  WebKitEngine target to hold it". A configure keeps the options of the one before it, so `-c` is what clears a stored `--component`.

## Status

The whole configure above completes on this machine, and `./xmakew deb -P .` writes `org.revenant.backports` with the Swift runtime,
libc++ and WebKit engine packages beside it. The probes of `frameworks/Backports/tests/device_probe` link (`BackportsDeviceProbe` and the
others that compile `src/Metal` or `src/MetalPerformanceShaders` into their own executable), and the component configure and build run.
