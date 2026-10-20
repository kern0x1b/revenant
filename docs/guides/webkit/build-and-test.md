# Build and test the port

## Requirements

**Device:** an iPhone 4S (armv7), iOS 6.1.3, jailbroken, with **MobileSubstrate/CydiaSubstrate**, a working TLS
shim on the device (the modern-TLS layer), and OpenSSH for deploys.

**Build host (macOS):** the Command Line Tools. The **iOS 16.4 SDK** arrives as the toolchain's `iphoneos-sdk` package,
fetched from [theos/sdks](https://github.com/theos/sdks) and checked against its sha256. Xcode is not needed, and neither
is Theos. revenant's `./xmakew` fetches `cmake`, `ninja`, `ldid` and the linker as packages.

Everything targets **armv7 with a 6.0 deployment target**, built with the **iOS 16.4
SDK** the toolchain's `iphoneos-sdk` package lays out. Current clang compiles C++23 for a
2011 phone, and what iOS 6 lacks of it is linked in from the toolchain's backports.

The port is a member of revenant and is built the way every member is, with `./xmakew` at the
top of the checkout:

```sh
./xmakew f -P . -p iphoneos -a armv7
./xmakew -P .                      # the engine packages, the tweaks and the Settings bundle
./xmakew deb -P .                  # space.kern0x1b.rev_<version>_iphoneos-arm.deb
./xmakew device install -P .       # the same, then dpkg -i on the phone device.env names
```

Host requirements: the Command Line Tools. xmake fetches the rest: the SDK, `cmake` and
`ninja`, `ldid` for ad-hoc signing and the linker come from the toolchain's packages.
Xcode is not needed and neither is Theos; `strip`, `otool`, `nm`, `plutil` and
`install_name_tool` are found through the Command Line Tools.

## 1. The engine source

The engine is upstream WebKit at one commit of `main` with this port as an ordered series of
patches, `third_party/webkit/patches/`. The `webkit` package in `third_party/webkit/xmake.lua`
fetches that commit by hash, as a sparse checkout of the folders the build reads, and applies
the series with `git apply`; each patch is pinned by its sha256 in the recipe. Nothing of the
engine is vendored and there is no fork to keep in step.

The series is the port: changing the engine means changing a patch, and the recipe's checksum
with it. How to move the base to a newer upstream commit is in
[core-update.md](../../explanation/webkit/core-update.md).

## 2. The libraries iOS 6 cannot supply

Each is an xmake package at its release, built for armv7 and iOS 6 by a recipe in
`third_party/`, or by the toolchain where every member shares it:

| Package | Version | Why the system copy will not do |
| --- | --- | --- |
| `libcxx` (toolchain) | 23.1.1 | iOS 6 ships a 2012 libc++; C++23 needs a current one |
| `icu` | 78.3 | the system ICU predates WebKit's minimum, and text segmentation with it has no zero-width joiner |
| `openssl` (toolchain) | 4.0.2 | TLS 1.2/1.3 and Web Crypto |
| `libpsl` | 0.23.3 | public-suffix lookups this CFNetwork does not do |
| `libwebp` | 1.6.0 | this ImageIO cannot decode WebP |
| `libxml2` | 2.15.4 | the system copy is 2.7.8 from 2010, older than the API libxslt and the SDK headers expect |
| `libxslt` | 1.1.45 | XSLT; the SDK has no libxslt headers or armv7 library |
| `woff2` | 2026.06.29 | web fonts in the format the web serves them; upstream has tagged nothing since 2017, so this is its latest commit |
| `brotli` | 1.2.0 | what woff2 decompresses with |
| `wasm3` | 0.9.1-beta.1 | the interpreter behind WebAssembly in Safari's compat dylib |

ICU is built with its data trimmed to the languages listed in the install script of `third_party/icu/xmake.lua`.

`libios6compat.a` - the symbols this OS predates, see
[compatibility.md](../../reference/webkit/compatibility.md) - is this port's own code in `src/compat/`, built by the
engine package before the engine itself. It holds only this port's own stubs; the engine
links OpenSSL and libpsl from their packages.

`tools/check-cacert.lua` builds nothing: it verifies the trust store the standalone
application carries against the hash this project reviewed, and with `--upstream` says
whether curl serves the same extract today. It is the `webkit-cacert` check:
`./xmakew check -P . webkit-cacert`.

## 3. The engine

`src/engine/xmake.lua` is the `webkit-engine` package, and `src/modules/engine.lua` holds
what it does: the CMake options and tuning flags of each variant, and the steps, in the
order that fails cheapest first:

1. `src/modules/carry.lua` - the patched tree still holds what this port needs (`carry-manifest.txt`)
2. `libios6compat.a`, then the engine through CMake and Ninja; configure is checked to have
   taken every path it was given and the project include
3. WebKitLegacy exports exactly the symbols its export list names
4. no compat stub shadows a definition WebKit has
5. `src/modules/symbols.lua` - the symbol surface matches `carry-symbols.txt`
6. `src/modules/stage.lua` - the frameworks laid out as the iOS 6 system frameworks they
   replace, beside the C++ runtime, as the device filesystem tree in the package's `stage/`,
   its plists binary and checked; and a `batteries/` folder with `jsc` for the tests

The tweaks and the Settings bundle are xmake targets in `xmake.lua` beside the package, built
with the toolchain's `tweak` rule, which checks every binary as it links. Why each CMake
setting has the value it has is in [engine-configuration.md](../../explanation/webkit/engine-configuration.md).

The package's identity includes a digest of its recipe, the modules, `src/compat/` and
`carry-symbols.txt`, so a change to any of them rebuilds the engine and nothing else does.

Three things about this build are worth knowing, because they explain choices
that look arbitrary otherwise.

**The engine is built without a class prefix.** The prefix exists so this engine
can sit in a process beside the system one. When a process takes our frameworks
through `DYLD_FRAMEWORK_PATH` the system engine is never loaded, there is
nothing to collide with, and UIKit needs the classes under their real names - it
links `_OBJC_CLASS_$_WebView`, not a prefixed spelling. The `webkit-engine` package
therefore builds the unprefixed engine by default; its `variant=prefixed` config builds
the prefixed one for the standalone application.

**The package arranges that build as the system frameworks a process expects**,
into `stage/usr/lib/rev-fw` rather than an application bundle,
which is what makes `DYLD_FRAMEWORK_PATH` substitution possible for Mobile
Safari: `WebKitLegacy` becomes `WebKit.framework`, every framework takes the
install name of the iOS 6 framework it stands in for (`JavaScriptCore` is a
private framework on this release), the C++ runtime is renamed
`librev-c++` so it cannot be mistaken for the system's, and nothing is left
depending on `@rpath`.

**Nothing in the compatibility library may define a symbol WebKit itself
defines.** A stub that shadows a real definition links cleanly and then fails at
runtime: `WebCoreWebThreadLock` is a function pointer in WTF and was a function
here, which turned a call into a store into `__TEXT` and a bus error.
The build checks for exactly that, every time it stages the engine.

**Every import has to exist on the phone.** The SDK the engine compiles against
is years newer than the system it runs on, so a call can link cleanly against a
function iOS 6 never had. Nothing fails at load: the import is bound lazily, and
the process dies the first time the call is made. A plain `ws://` WebSocket did
exactly that. The toolchain's rules compare every non-weak import of what they link
with what the phone's own shared cache exports, once `xmake firmware` has fetched it.

**A change to a WebCore header means a full build.** A partial build leaves
WebKit and WebKitLegacy compiled against the old class size, and the result loads
and then behaves wrongly — empty text in the interface, and a silent death with no
crash log. This has cost more than one debugging session. The package builds the engine
whole every time its identity changes.

The prefixed variant builds the same source with the class prefix applied, for a build
that has to coexist with the system engine in one process. The shipped build is the
unprefixed one; see [architecture.md](../../explanation/webkit/architecture.md#two-webkits-in-one-process).

## 4. The package

```sh
./xmakew deb -P .
```

`RevSafari` carries the package: its target names `src/packaging/control` and
`src/packaging/DEBIAN`, and installs the engine package's `stage/` tree at the root of the
`.deb`, beside `RevSafari.dylib` and its MobileSubstrate filter, `rev-safari-compat.dylib`,
`rev-TLS.dylib` and `RevPrefs.bundle` with its PreferenceLoader entry. The version is
`version` in `xmake.lua`; `src/packaging/control` carries none of its own.

Two settings on the `rev-safari-compat` target are not optional: the compat dylib is
built without `_FORTIFY_SOURCE` and without libc++ (`-nostdlib++`), because the `__*_chk` symbols
are linkage this release never had and the engine carries its own C++ runtime — a
second one in the same process is a crash waiting to happen.

## 5. Onto the device

Copy `device.env.example` to `device.env` at the top of the revenant checkout and fill in the
address; neither is in the repository.

```sh
./xmakew device install -P .
```

## The engine without Safari

`examples/webview-host/rev-webview-host.m` is a plain UIKit view controller around one `WebView`:
no tabs, no chrome, one URL. It exists for two reasons.

**As a harness.** It links the engine and `ModernTLSURLProtocol` and nothing
else, so it answers questions about the engine with no `MobileSubstrate`, no
respring and no Safari in the way — and a crash is a crash of one process you
own, with its own log at `/tmp/rev-webview-host.log`. It is also the direct
`WebView` path rather than the substitution path: `UIWebBrowserView` cannot host
this engine, because it drives its view through the *system* WebCore's
`WKWindowSetContentView`, so the window and layer are built here by hand the way
`UIWebView`'s own implementation would.

```sh
./xmakew build -P . RevWebViewHost
./xmakew device -P . run "uiopen revwebviewhost:"
./xmakew device -P . log
```

`RevWebViewHost` is an app target built on demand with the toolchain's `app` rule, against
the `webkit-engine` package's prefixed variant: the engine and the C++ runtime are bundled
inside it, and its version is `version` in `xmake.lua`. It opens through its
`revwebviewhost:` scheme. It needs the device address in `device.env` at the top of the
checkout, as everything that reaches the phone does.

**As an embedding surface.** Compiled with `-DREV_WEBVIEW_HOST_NO_MAIN` the file
carries no `main()`, and `RevWebViewHostControlling` in
`examples/webview-host/RevWebViewHostEmbedding.h` is the whole interface another application
drives it through — load, back, forward, reload, stop, a content frame, and a
delegate that reports title, progress, URL, scroll offset and failures. That is
the consumer the app-shell cache policy in [network.md](../../explanation/webkit/network.md) was written
for: a wrapped site that has to launch like a native application. Nothing in
this repository embeds it today; it is a capability, kept because the
substitution path cannot serve an application that is not Safari.

### What hosting the engine by hand requires

Four things this file had to learn, for anyone embedding it:

- **A root-layer handler must exist.** `WebKitUIKitDelegate` calls
  `-attachRootLayer:` with no `respondsToSelector:` guard, so without it the
  first promoted layer — `position: fixed` content, by default — kills the
  process with an unrecognized selector. The host layer is already in document
  coordinates, which is where `GraphicsLayer` puts the root layer, so parenting
  it needs no extra geometry.
- **Touches have to be posted.** WebKitLegacy takes them as `WebEvent`s sent to
  the `WAKWindow`; there is no automatic path from UIKit, and without it a
  correctly painted page looks frozen. A drag needs a pan recognizer rather than
  raw `touchesMoved:` forwarding, which arrives as stuttering fragments.
- **The keyboard follows WebKit's own focus.** `WebFormDelegate` reports a text
  field taking and losing focus, which is the native, poll-free signal to raise
  a hidden `UIKeyInput` view. Only that view may become first responder: making
  the `WebView` the WAK first responder blurs the focused field and bounces the
  keyboard straight back down. Resigning is debounced, because a tap moving
  focus between fields fires end-then-begin.
- **The host layer has to be resized to the document.** Otherwise a page taller
  than the initial viewport clips instead of scrolling.

## Verifying an injected dylib will load

A dylib can compile clean and still be refused by dyld, silently. The build's
imports check covers what it links against; two things it cannot see are worth
looking at in the staged tree the package is made from:

```sh
otool -L <stage>/usr/lib/rev-safari-compat.dylib
otool -l <stage>/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib | grep LC_ENCRYPTION_INFO
```

The second must print nothing. Apple's linker from Xcode 27 writes that load
command into armv7 dylibs, and iOS 6 then never starts the app the tweak is
injected into; the tweak dylibs link through ld64 for exactly this reason.

- The loader links only `libSystem` and `CoreFoundation`, with install name
  `/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib`.
- The compat dylib framework-links Foundation, CoreFoundation, objc and sqlite3,
  with install name `/usr/lib/rev-safari-compat.dylib`.

Never `-undefined dynamic_lookup` a dylib that is eligible for the shared cache,
and never change a dylib's install name away from where it is deployed.

## Reading a crash

The engine installs a fault handler that prints, for each thread, the program
counter and the address the access was for. The backtrace below it is a chain of
*return* addresses, so its innermost frame is the caller of the function that
faulted, not the fault — symbolising that frame is an afternoon spent on the
wrong function. `backtrace_symbols_fd` names the nearest exported symbol, which
in a library this size is usually the wrong one for the same reason.

What makes a frame exact is the load slide, which the handler prints for every
engine image:

```sh
atos -o WebCore -l <slide> <address>
```

The handler runs on a stack of its own, because a stack overflow faults on the
guard page and would otherwise die without printing anything at all.

## Checking it took

The user agent is the test: a page that echoes it — or the engine's own log at
`/tmp/rev-safari-stderr.log` — should report `AppleWebKit/605`, not `536`.

Then run the numeric suite, which reads pixels and glyph widths rather than
screenshots: [`tests/device/run.lua`](../../reference/webkit/device-suite.md).

## The toolchain this port needs, and how little of it is Apple's

macOS 27 replaced the linker with ld-27037.1 and broke two things for armv7 at
once. The first is fixed at the source; the second is what this section is
really about.

**OpenSSL's ARM assembly.** The new linker asserts on any named atom in a
`__nl_symbol_ptr` section:

    ld: Assertion failed: (kindIs(Atom::Kind::anon)), function setGotCoalescable

clang emits those slots as local labels, so only hand-written assembly can
produce one. OpenSSL's ARM generator does, for the capability word every
NEON-dispatching module reads, and a single such object in an archive kills the
link whether or not anything references it. The toolchain's `openssl` package patches
the generator - the ios32 branch of `$comm` in `crypto/perlasm/arm-xlate.pl` -
to emit a plain data word instead. Same address, same label name, no GOT atom.
Eight objects were affected; all of them link now, with the assembly kept.

**Reach.** WebCore's `__text` is about 25MB. A Thumb branch reaches 16MB, and
the call stubs are placed after all text, so code in the low third cannot reach
a stub at all. Apple's current linker gives up there. ld64-956.6 does not: it
inserts branch islands that bridge the distance, and it is what links the
engine. It was once recorded here as failing the same way; that came from
appending the test flags to the wrong command in a `&&` chain, and was wrong.

Things that do not work, so nobody tries them twice: `-ld_classic` is ignored
and the binary is gone; `-branch_island_region_size` governs island regions
between text sections, not stub placement; `-mlong-calls` cures the reach and
replaces it with text relocations, which would make `__TEXT` pages dirty at
load - the wrong trade on a device that is killed for dirty memory; lld has no
32-bit ARM Mach-O backend at all.

**Nothing here needs Xcode.** The toolchain can be assembled from parts that
outlive any macOS release:

- the compiler: any recent LLVM, Homebrew's `llvm` is enough - `armv7-apple-ios6.0`
  is a supported target;
- the linker: the `ld64` package from the toolchain - ld64 956.6 built from
  `cctools-port`, which supports armv7, reads `.tbd` stubs through
  `apple-libtapi`, and does LTO through the same LLVM;
- the SDK: the iOS 16.4 SDK from theos/sdks, which has never depended on
  Xcode.

The `ld64` recipe carries the two snags in building it: `apple-libtapi` calls
`get_darwin_linker_version`, a CMake helper its vendored LLVM does not ship, so
the call is guarded and `HOST_LINK_VERSION` set by hand; and cctools' bundled
`llvm-c/lto.h` wants headers from a newer LLVM, so it is configured against
Homebrew's.

## Deploy and test

The device address and password are not in the repository. Copy the example and fill it in:

```sh
cp frameworks/WebKit/tests/data/device.env.example device.env    # at the top of revenant: DEVICE_HOST / DEVICE_PORT
```

Then build and install the package, which carries the loader, the compatibility dylib, the TLS dylib and the Settings
pane, and can be removed again:

```sh
./xmakew device install -P .
```

**Verify it took.** Open any page in Safari and check the user agent: a request to a service that echoes it, or the
on-device engine log at `/tmp/rev-safari-stderr.log`, should show `AppleWebKit/605`, not `536`. The stock engine renders
modern Google and YouTube broken; the port renders them.

**Screenshots from the device:** `/usr/bin/shot` writes `/tmp/screenshot.png`; `scp` it back.

**Iterating on the Settings pane** does not need a respring: redeploy `RevPrefs.bundle`, then `killall Preferences` and
reopen it.

The numeric device suite is `frameworks/WebKit/tests/device/run.lua`, run with `./xmakew l`;
[the device suite](../../reference/webkit/device-suite.md) describes what it measures. The host and browser batteries
are in [tests](../../reference/webkit/tests.md).

