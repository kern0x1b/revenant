---
name: build
description: Build the WebKit engine and the Safari-substitution artifacts (loader, compat dylib, Settings PreferenceBundle) for armv7 / iOS 6. Use when compiling any part of Revenant WebKit on the macOS host.
---

# Building Revenant WebKit

Everything targets **armv7, iOS 6.0 deployment**, built with the **iOS 16.4 SDK**
the `apple-ios` platform names, which the toolchain's `iphoneos-sdk`
package fetches and verifies. `cmake`, `ninja`, `ldid`, `ld64` and the SDK come
from Conan, not `PATH`; Theos is not used.

## Engine

```sh
./fetch-source.py     # webkit-254, a submodule on the fork's main branch
```

One command builds the libraries iOS 6 predates (declared in `charon.toml`,
pinned in `conan.lock`), `libios6compat.a` and the engine:

```sh
charon build
```

It builds into `build/system`; `charon build --variant prefixed` builds the
standalone application's engine into `build/prefixed`. Unchanged
libraries come from the Conan cache. ccache is used only when set as the
compiler launcher through `tools.cmake.cmaketoolchain:extra_variables`
(`CMAKE_<LANG>_COMPILER_LAUNCHER` for C, CXX, OBJC and OBJCXX) in one's own
`global.conf` or profile.

A change to a WebCore header means a full `charon build` — a partial build leaves the
other frameworks on the old class size, and the result loads and misbehaves with
no crash log. `docs/building.md` has the whole sequence.

`build/` is gitignored and reproducible.

## Safari-substitution artifacts

The same `charon build` finishes them. Its steps are `[pipeline]` in
`charon.toml`: `task:carry-check` runs first, before `build:static-library`;
after the engine come `check:exports`, `task:compat-audit` and
`task:symbol-check`; then it builds loader, compat, TLS and prefs from the
device libraries `charon.toml` declares (`build:device-library`) and lays
everything out as the device filesystem in `build/system/stage` (frameworks in
`stage/usr/lib/rev-fw`). The `prefixed` pipeline adds `task:prefix-exports`
before the libraries and has no `task:symbol-check`. Every binary is stripped
and signed with `ldid -S`.

```sh
charon package
```

packs that stage and copies
`space.kern0x1b.rev_<version>_iphoneos-arm.deb` into `build/<variant>/`,
printing `package <path>`. The version is `version` in `charon.toml`.

Every build ends its pipeline with `check:imports`, which refuses anything staged
or bundled that imports a symbol iOS 6 does not export, checked against the
phone's shared cache held in `~/.charon/dyld`. With the phone attached,
`charon test --tier imports` fetches that cache once per machine; after that the
build never needs the phone.

A step of your own is a task in `charon.toml` - `[tasks.NAME]` with `script`,
`shell` or `python` - placed in `[pipeline]` as `task:NAME`, or run alone with
`charon task NAME`.

## After building an injected dylib — always verify it will load

A dylib can compile clean and still refuse to load on iOS 6 (dyld gives up
silently). Before deploying:

```sh
otool -L build/system/stage/usr/lib/rev-safari-compat.dylib     # dependencies must match the on-device working copy
nm -u build/system/stage/usr/lib/rev-safari-compat.dylib | c++filt | less   # undefined symbols sanity
```

- The **loader** (`RevSafari.dylib`) links only `libSystem` + `CoreFoundation`,
  install_name `/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib`.
- The **compat dylib** framework-links Foundation/CoreFoundation/objc/sqlite,
  install_name `/usr/lib/rev-safari-compat.dylib`.

Do not `-undefined dynamic_lookup` a shared-cache-eligible dylib, and do not
change a dylib's install_name away from the path it is deployed to.

See `.claude/skills/deploy` next, and `.claude/skills/debug` if a build loads but
does nothing on device.
