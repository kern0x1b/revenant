# Revenant WebKit

**A current WebKit for hardware the web left for dead.**

A modern WebKit engine, built from source for **armv7**, running today's websites
on an **iPhone 4S from 2011** — a dual-core 800 MHz phone with 512 MB of RAM, on
**iOS 6.1.3**. The engine is dropped underneath the phone's own **Mobile Safari**,
so the stock browser renders the modern web with none of its own UI replaced.

The engine the phone ships with is WebKit 536 from 2012. It cannot render a page
written this decade — a modern sign-in form comes back with no input elements at
all, because the script that builds it never runs. Nor can the phone still
negotiate TLS with a current server, or perform the cryptography a login form
needs. Each of those is fixed here.

<p align="center">
  <img src="docs/screenshots/browser-modern-web.png" alt="The bookmarks start page, the Speedometer benchmark and the Internet Archive rendered on an iPhone 4S" width="100%">
  <br>
  <em>The new-tab start page, WebKit’s own Speedometer benchmark, and the Internet Archive — on an iPhone 4S, in Mobile Safari.</em>
</p>

<p align="center">
  <img src="docs/screenshots/browser-and-settings.png" alt="OpenStreetMap, Wikipedia and the RevWebKit settings pane" width="100%">
  <br>
  <em>OpenStreetMap, Wikipedia, and the RevWebKit Settings pane.</em>
</p>

## Contents

- [What works](#what-works)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Build](#build)
- [Deploy and test](#deploy-and-test)
- [The Settings pane](#the-settings-pane)
- [Repository layout](#repository-layout)
- [Notes and design](#notes-and-design)
- [License](#license)

## What works

- **Current WebKit**, built from source for armv7 with a 6.0 deployment target:
  current C++ compiled for a 2011 phone.
- **Real Mobile Safari on the new engine.** A MobileSubstrate tweak re-launches
  Safari with the engine forced underneath it; the user agent reports
  `AppleWebKit/605` instead of the stock `536`. UIKit's own gestures, scrolling
  and text selection are reused unchanged.
- **JavaScript with a JIT.** Upstream deleted the ARMv7 JIT; it is restored here,
  with the regressions that restoring it caused fixed as well.
- **TLS 1.2 / 1.3.** The system's TLS is from 2012 and current servers refuse its
  cipher suites. The port answers the system's TLS calls over OpenSSL, so the
  browser reaches sites the phone otherwise cannot open. Certificate verification
  is unchanged — the chain is evaluated by the system as a real `SecTrustRef`.
- **Web Crypto**, performed by WebKit's own OpenSSL backend rather than the Cocoa
  one, which works in CryptoKit and has no armv7 Swift: digests, HMAC, AES in GCM,
  CBC, CFB and CTR, AES key wrapping, HKDF, PBKDF2, ECDSA, ECDH, RSA-OAEP and
  RSASSA-PKCS1 all verified on the device.
- **WebAssembly** (via a bundled interpreter, since JSC's WASM is
  64-bit only), **Web Notifications**, **getUserMedia** (camera + microphone),
  `<video>` MediaStream preview, and a wave of self-contained web APIs enabled by
  default.
- **WebGL.** `canvas.getContext("webgl")` returns a real context: shaders
  compile, and the GPU draws. Upstream's only GL backend goes through ANGLE's
  Metal renderer, which needs an A7, so this port carries an ANGLE backend on
  EAGL - the GLES API this hardware does have. WebGL 2.0 needs OpenGL ES 3.0 and
  this silicon is an ES 2.0 part; that is a ceiling, not a milestone.
  [docs/webgl.md](docs/webgl.md) has how it was built and what is left.
- **Web fonts and form controls.** Both were entirely absent rather than
  approximate: no `@font-face` had ever loaded a font in any format, and every
  button, field, checkbox and select was painted in a fully transparent colour.
  Sites now draw with their own typefaces and their controls can be read.
- **Scrolling inside a page.** Overflow blocks and frames are scrolled by the
  system's own `UIWebOverflowScrollView`, the way this release of iOS does it,
  which is what makes cookie dialogs and any other inner scroller usable.
- **The image formats the web actually serves.** WebP is decoded by WebKit's own
  decoder, since this ImageIO cannot; the formats that remain undecodable are no
  longer advertised to servers, which had been negotiating pictures the browser
  could not render.
- **Colour, measured rather than eyeballed.** Gradients interpolate premultiplied,
  every blend mode including the four non-separable ones is reached through
  CoreGraphics, and SVG filters interpolate in linear light and read back the
  numbers the specification asks for. This graphics library matches colour spaces
  by primaries and ignores transfer functions, so the engine performs those
  conversions itself, the way ports without colour management do.
- **Joined emoji shape as one glyph.** An astronaut, a family, a skin tone - one
  glyph each rather than their parts, which needed the character break iterator
  to use ICU rather than 2012 rules with no zero-width-joiner in them. What the
  device can *draw* is a question about the font it has, and that is not this
  project's business: the font stays where it is.
- **A native Settings pane** (`RevWebKit`) for the new-tab start page, a custom
  home URL, and per-app engine injection. See [The Settings pane](#the-settings-pane).

Correctness is checked by a numeric suite that runs on the device and reads
pixels, glyph widths and the platform surface rather than screenshots:
`tests/device/run.py`, currently **57 of 57**. Alongside it,
`tests/device/sweep.py` loads real sites and reports whether each one survived,
painted, and what it cost in memory - the failures that only the actual web
produces do not show up in a suite that checks its own numbers. Both are described
in [tests/device/README.md](tests/device/README.md).

## How it works

The engine lives in the dyld shared cache, so there is no file to replace and no
way to swap it for one process only. Instead a small loader is injected into the
launching app, sets `DYLD_FRAMEWORK_PATH` / `DYLD_INSERT_LIBRARIES` to point at
the port's engine, and re-execs the app. The second launch loads the new engine
first. Three artifacts do this:

| Artifact | On device | Built by | Role |
| --- | --- | --- | --- |
| **Loader** | `/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib` | the `RevSafari` device library in `charon.toml` | Reads the enabled-apps preference and re-execs an enabled app with the engine's `DYLD_*` set. Skips SpringBoard. |
| **Engine** | `/usr/lib/rev-fw/{JavaScriptCore,WebCore,WebKit}.framework` | `charon build` from `charon.toml`, which also lays it out under the system's names | The WebKit build itself. |
| **Compat / hooks** | `/usr/lib/rev-safari-compat.dylib` | the `rev-safari-compat` device library in `charon.toml` | The ABI symbols iOS 6 predates, plus the bookmarks start page, WebAssembly, and preference reads. Inserted by the loader. |

The loader and the compat dylib are two different files with two different jobs —
overwriting one with the other drops Safari back to the system engine.

## Requirements

**Device**

- iPhone 4S (armv7), iOS 6.1.3, jailbroken, with **MobileSubstrate/CydiaSubstrate**.
- A working TLS shim on the device (the modern-TLS layer) and OpenSSH for deploys.

**Build host** (macOS)

- The Command Line Tools. The **iOS 16.4 SDK** the `apple-ios` platform names
  arrives as the toolchain's `iphoneos-sdk` package, fetched from [theos/sdks](https://github.com/theos/sdks)
  and checked against its sha256. Xcode is not needed, and neither is Theos.
- `conan`, and [Charon](https://github.com/kern0x1b/charon)
  installed with `conan config install`. Conan itself installs `cmake`, `ninja`,
  `ldid` and the `ld64` linker.

## Build

```sh
./fetch-source.py          # the engine, a git submodule on the fork's main branch
```

Then the libraries this OS cannot supply, the engine, and the package. The whole
sequence, and why each piece exists, is in **[docs/building.md](docs/building.md)**:

| Step | Builds |
| --- | --- |
| `charon build` | the libraries iOS 6 predates, `libios6compat.a`, the engine and everything around it, laid out as the device filesystem in `build/system/stage` |
| `charon package` | the `.deb` |

A change to a WebCore header means a full build, which `charon build` is: a
partial build leaves the other frameworks compiled against the old class size,
and the result loads and then misbehaves with no crash to read.

### The Safari substitution, as a package

`charon build` lays out the engine as the system frameworks it replaces, and
builds everything that goes on the device around it from the device libraries
`charon.toml` declares. `charon package` packs that tree into
`<package folder>/deb/space.kern0x1b.rev_<version>_iphoneos-arm.deb`.
The version is `version` in `charon.toml` - change it there and build.

One `.deb` carries all of it: the loader and its MobileSubstrate filter, the
compatibility and hook dylib, the TLS library, the Settings bundle with its
PreferenceLoader entry, and the engine frameworks. Install it the way any tweak
is installed:

```sh
dpkg -i space.kern0x1b.rev_*_iphoneos-arm.deb
```

Two settings on the `rev-safari-compat` device library in `charon.toml` are not
optional: the compat dylib
is built without `_FORTIFY_SOURCE` and without libc++, because the `__*_chk`
symbols are linkage this release never had, and the engine carries its own C++
runtime — a second one in the same process is a crash waiting to happen.

## Deploy and test

The device address and password are **not** in the repository. Copy the example
and fill it in:

```sh
cp device.env.example device.env    # set DEVICE_HOST / DEVICE_PORT / DEVICE_PASSWORD
```

Then build and install the package, which carries the loader, the compatibility
dylib, the TLS dylib and the Settings pane, and can be removed again:

```sh
charon build
charon package
charon device copy "<package folder>/deb/space.kern0x1b.rev_<version>_iphoneos-arm.deb" /tmp/rev.deb
charon device run 120 "dpkg -i /tmp/rev.deb"
```

**Verify it took.** Open any page in Safari and check the user agent — a request
to a service that echoes it (or the on-device engine log at
`/tmp/rev-safari-stderr.log`) should show `AppleWebKit/605`, not `536`. The stock
engine renders modern Google/YouTube broken; the port renders them as above.

**Screenshots from the device:** `/usr/bin/shot` writes `/tmp/screenshot.png`;
`scp` it back. This is how the images in this README were made.

**Iterating on the Settings pane** does not need a respring — redeploy
`RevPrefs.bundle`, then `killall Preferences` and reopen it.

## The Settings pane

Installed as **`RevWebKit`** in the system Settings app, as a real
PreferenceBundle. It writes the `space.kern0x1b.rev` preferences domain that the engine
reads:

- **Bookmarks start page** — a blank tab renders your Safari bookmarks as tiles.
  Turning it off collapses the rest.
- **Custom Home URL** — open a fixed page on every new tab instead. A URL with no
  scheme is opened over `https`.
- **Per-App Injection** — a list of installed apps; the engine is injected only
  into the ones turned on (Safari by default). Injecting the engine into an
  arbitrary app is experimental and reversible (turn it off and respring).
- **Respring** — restart SpringBoard from the pane.

<p align="center">
  <img src="docs/screenshots/settings-revwebkit.png" alt="The RevWebKit settings pane" width="45%">
</p>

## Repository layout

```
app/            The standalone application: the embeddable host for the web view
compat/         Symbols iOS 6 does not have, built into libios6compat.a
docs/           Documentation and the screenshots in this README
packaging/      The package's control file and DEBIAN scripts
platform/       The tweak, compat and TLS dylibs and the Settings bundle, built with CMake
  safari/       The Safari substitution: the loader, the compat/hooks, WebAssembly and TLS sources
  prefs/        The RevWebKit Settings PreferenceBundle
  device/       What is installed on the phone beside the engine
recipes/        Conan recipes for the libraries iOS 6 cannot supply
scripts/        The check scripts the declaration names, and maintenance and device helpers
tests/          The numeric device suite, host tests, and JS conformance checks
tools/          Diagnostic instruments, on the host and on the device
webkit-254/     The engine, a git submodule on the fork's main branch
```


## Documentation

**How it works**

| Document | What is in it |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | How the engine is loaded in place of the system one, and what that costs |
| [docs/network.md](docs/network.md) | HTTPS on a system whose TLS stopped working: the OpenSSL layers, the HTTP cache, the app-shell policy |
| [docs/compatibility.md](docs/compatibility.md) | What this OS does not have, probed on the device, and the rule that no shim may answer success while doing nothing |
| [docs/memory-and-caches.md](docs/memory-and-caches.md) | What 512 MB forces: the JS heap, the cache model, tiles, memory pressure |
| [docs/webgl.md](docs/webgl.md) | The ANGLE backend this port had to write, and what the GPU still refuses |

**Working on it**

| Document | What is in it |
| --- | --- |
| [docs/building.md](docs/building.md) | The full build, step by step, the standalone host, and how to verify a dylib will load |
| [tests/device/README.md](tests/device/README.md) | What the on-device suite measures, and the limitations it records |
| [tests/README.md](tests/README.md) | The ICU and JavaScript batteries, and the benchmarks meant for a browser |
| [docs/tools.md](docs/tools.md) | The probes in `tools/`, and the question each one answers on the device |
| [docs/upstream.md](docs/upstream.md) | Fixes this port carries that are WebKit's bugs, not iOS 6's, waiting to go back |
| [docs/maintaining.md](docs/maintaining.md) | How this port is carried against a moving engine: the carry manifest, the test pyramid, and what an update runs |
| [docs/core-update.md](docs/core-update.md) | Moving the port onto a newer engine branch |

**For the record**

| Document | What is in it |
| --- | --- |
| [CHANGELOG.md](CHANGELOG.md) | Every change, dated by the day it was measured on the device |
| [THIRD-PARTY.md](THIRD-PARTY.md) | Every dependency, its licence, and where its source comes from |
| [docs/armv7-jit.md](docs/armv7-jit.md) | Carrying a 64-bit NaN-boxed JSValue on ARMv7, for the day the branch drops it |
| [docs/history.md](docs/history.md) | How the project started, kept as history |

## Trademarks and screenshots

The screenshots show third-party websites rendered by this engine, as examples of
what it displays on the device. All names, logos, page designs and content in
them remain the property of their respective owners and are shown nominatively -
to demonstrate a browser engine working - under fair use. This project is not
affiliated with, endorsed by, or sponsored by any of them, and ships none of
their code, assets or branding.

Nor does anything here drive a browser at somebody else's site on its own: the
automated suite loads pages served from this repository, and the one script that
can load a real site takes the list from the operator. See
[THIRD-PARTY.md](THIRD-PARTY.md).

## License

MIT, see `LICENSE`, for the code in this repository: the compatibility library,
the tooling, the tests, the packaging and the documentation.

The engine is WebKit and keeps its own terms - LGPL-2.1-or-later and
BSD-2-Clause - and this port's changes to it are commits on the `main`
branch of the `webkit-254` submodule, under those same terms.

Nothing third-party is vendored here. Every library this operating system
cannot supply is fetched from its own upstream by a Conan recipe under
`recipes/`, at a pinned version. [THIRD-PARTY.md](THIRD-PARTY.md) lists each one,
its version, its license, and the recipe that fetches it - and what this project
deliberately does not carry, including anybody else's fonts, pages or test
suites.

Built with Claude (Anthropic). This project is developed with AI assistance,
openly — see the commit history.
