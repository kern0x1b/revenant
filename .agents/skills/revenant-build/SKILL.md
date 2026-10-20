---
name: revenant-build
description: Build the WebKit engine and the Safari-substitution artifacts (loader, compat dylib, Settings PreferenceBundle) for armv7 / iOS 6. Use when compiling any part of Revenant WebKit on the macOS host.
---

# Building Revenant WebKit

Everything targets **armv7, iOS 6.0 deployment**, built with the **iOS 16.4 SDK**
the toolchain's `iphoneos-sdk` package fetches and verifies. `cmake`, `ninja`, `ldid`,
`ld64` and the SDK are xmake packages, not `PATH`; Theos is not used. xmake is always
`./xmakew` from the top of the checkout, with `-P .`.

## Engine

The engine is upstream WebKit at one commit plus the port's patch series:
`third_party/webkit/xmake.lua` names the commit and each patch's sha256, and
`third_party/webkit/patches/` holds the series. The `webkit` package fetches the commit
and applies the series; nothing of the engine is checked in.

```sh
./xmakew f -P . -p iphoneos -a armv7
./xmakew -P .
```

Configuring requires the `webkit-engine` package (`frameworks/WebKit/packages/engine`)
in its two variants, `system` and `prefixed`, and the libraries iOS 6 predates, which
are packages in `third_party/` and the toolchain. Unchanged packages come from the store.

A change to a WebCore header means a full engine build — a partial build leaves the
other frameworks on the old class size, and the result loads and misbehaves with
no crash log. The package always builds the engine whole; a change to the series,
the recipe, `frameworks/WebKit/modules/`, `compat/` or `carry-symbols.txt` changes its
identity and rebuilds it. `docs/guides/webkit/build-and-test.md` has the whole sequence.

A change to the engine is a change to a patch: in a scratch clone of WebKit at the
base commit, `git am` the series, change the commit it belongs to, `git format-patch`
the series back into `third_party/webkit/patches/`, and put the new sha256 in the recipe.

## Safari-substitution artifacts

`frameworks/WebKit/modules/engine.lua` runs the engine's steps: the carry check
first, then `libios6compat.a`, the engine through CMake and Ninja, the export check,
the compat audit and, for the system variant, the symbol check against
`carry-symbols.txt`; `modules/stage.lua` lays it out as the device filesystem in the
package's `stage/` (frameworks in `stage/usr/lib/rev-fw`), strips and signs every
binary. The prefixed variant writes its export list first and bundles the frameworks
for the standalone application instead.

The loader, compat, TLS and prefs are targets in `frameworks/WebKit/xmake.lua` built
with the toolchain's `tweak` rule, which checks every binary as it links, including
its imports against the phone's shared cache once `xmake firmware` has fetched it.

```sh
./xmakew deb -P .
```

writes `space.kern0x1b.rev_<version>_iphoneos-arm.deb` with the engine's stage in it.
The version is `version` in `frameworks/WebKit/xmake.lua`.

## After building an injected dylib — always verify it will load

A dylib can compile clean and still refuse to load on iOS 6 (dyld gives up
silently). Before deploying, in the staged tree:

```sh
otool -L <stage>/usr/lib/rev-safari-compat.dylib     # dependencies must match the on-device working copy
nm -u <stage>/usr/lib/rev-safari-compat.dylib | c++filt | less   # undefined symbols sanity
```

- The **loader** (`RevSafari.dylib`) links only `libSystem` + `CoreFoundation`,
  install_name `/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib`.
- The **compat dylib** framework-links Foundation/CoreFoundation/objc/sqlite,
  install_name `/usr/lib/rev-safari-compat.dylib`.

Do not `-undefined dynamic_lookup` a shared-cache-eligible dylib, and do not
change a dylib's install_name away from the path it is deployed to.

See `revenant-deploy` next, and `revenant-debug` if a build loads but does nothing on device.
