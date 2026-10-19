# Building the port

Everything targets **armv7 with a 6.0 deployment target**, built with the **iOS 16.4
SDK** the `apple-ios` platform names. Current clang compiles C++23 for a 2011 phone,
and what iOS 6 lacks of it is linked in from the toolchain's `apple-compat`.

Host requirements: `conan` and the Command Line Tools. Conan installs the rest,
the SDK included - `iphoneos-sdk` fetches it from [theos/sdks](https://github.com/theos/sdks):
`cmake` and `ninja` from ConanCenter, `ldid` (ad-hoc signing) and the `ld64`
linker from Charon. Xcode is not needed and is not installed here, and
neither is Theos - the Command Line Tools carry the compiler and its runtime,
and `strip`, `otool`, `nm` and `install_name_tool` are found through them. The
Python that runs WebKit's generators and the check scripts is the one Conan runs
in; nothing is taken from `PATH`.

The first build of `ld64` on a machine also needs an LLVM, because cctools'
configure runs `llvm-config` to find `libLTO`; Charon reads the path
from `LLVM_PREFIX` once, so `export LLVM_PREFIX="$(brew --prefix llvm)"` before
it. Afterwards the package is in the Conan cache and nothing asks again.

The SDK reaches the build as `tools.apple:sdk_path`, which the toolchain's
`iphoneos-sdk` package answers: the `apple-ios` platform requires it for every
build, and it downloads the SDK archive once, checks its sha256 and lays it out
as Xcode does. A `tools.apple:sdk_path` set in a profile still wins.

ccache is not picked up on its own. To use it, set the compiler launchers in
your own `global.conf` or profile; `compat/`, `platform/` and the engine all
build with the same generated `conan_toolchain.cmake`, so this covers all three:

```
tools.cmake.cmaketoolchain:extra_variables={"CMAKE_C_COMPILER_LAUNCHER": "ccache", "CMAKE_CXX_COMPILER_LAUNCHER": "ccache", "CMAKE_OBJC_COMPILER_LAUNCHER": "ccache", "CMAKE_OBJCXX_COMPILER_LAUNCHER": "ccache"}
```

## 1. The engine source

```sh
./fetch-source.py
```

`webkit-254` is a git submodule tracking the `main` branch of a WebKit fork,
where this port's engine changes live as real commits. There is no patch series to
apply.

## 2. The libraries iOS 6 cannot supply

They are declared, not scripted. `charon.toml` names them and `conan.lock` pins
the exact recipe and binary of each; `recipes/` holds the recipe for every one,
and each names a git URL and a commit rather than vendoring a copy:

| Package | Why the system copy will not do |
| --- | --- |
| `libcxx/23.1.1@charon/stable` | iOS 6 ships a 2012 libc++; C++23 needs a current one |
| `icu/78.3@revenant/stable` | the system ICU predates WebKit's minimum, and text segmentation with it has no zero-width joiner |
| `openssl/4.0.2@revenant/stable` | TLS 1.2/1.3 and Web Crypto |
| `libpsl/0.23.3+5.ga629c83@revenant/stable` | public-suffix lookups this CFNetwork does not do |
| `libwebp/1.6.0+258.g6ff2f43@revenant/stable` | this ImageIO cannot decode WebP |
| `libxml2/2.15.4@revenant/stable` | the system copy is 2.7.8 from 2010, older than the API libxslt and the SDK headers expect |
| `libxslt/1.1.45@revenant/stable` | XSLT; the SDK has no libxslt headers or armv7 library |
| `woff2/1.0.2+13.gfb9c337@revenant/stable` | web fonts in the format the web serves them |
| `brotli/1.2.0+161.g85c2aaf@revenant/stable` | what woff2 decompresses with |

The user and channel are not decoration. ConanCenter publishes packages under
these same names, Conan asks remotes in the order they were registered, and a
wrong order does not fail - it quietly builds against a recipe that cannot
cross-compile for armv7. The namespace makes a bare `icu/78.3` unresolvable
from these indexes, so a reference that forgets it is an error instead.

`@charon/stable` belongs to what Charon serves and every port shares.
The libraries this port builds for itself are `@revenant/stable`: another port
on the same machine builds its own OpenSSL with its own choices, and two recipes
behind one reference overwrite each other's packages in the shared cache.

The target is `[platform] use = "apple-ios"` with armv7 and iOS 6.0 in
`charon.toml`; the toolchain's platform file says what is true of that target.
What is this port's own - C++23, and tuning for the Cortex-A9 in the iPhone 4S
and iPad 2 - is `[target]`, and Charon writes the whole profile from both. A 3GS is a
Cortex-A8, and another port on the same toolchain has no reason to inherit
either choice.

Register the two indexes once, the toolchain's and this repository's:

```sh
charon setup <charon>
```

That installs the toolchain's configuration - profiles, settings, hooks and
Charon itself - and registers both recipe indexes ahead of the general remotes.
`charon build`, `charon deploy`, `charon test` and the rest are Charon itself; it
lives in the toolchain, not here, so every port gets the same verbs. This
repository declares itself to it in `charon.toml` and carries nothing else of the
build. The phone's address comes from `device.env` at the root of the
checkout, and from nowhere else.

`conan config install` copies rather than references, so run `charon setup` again
after the toolchain changes. `charon provenance` says which copy is answering.

`charon build` writes `build/system/conan/charon-deps.env` through the
`charon-base` generator, straight from the dependency graph - one
`CHARON_HOST_<NAME>=path` line per library and `CHARON_BUILD_<NAME>=path` per build
tool, so `CHARON_BUILD_LD64` is the linker. Nothing names a version, an
architecture or a folder layout. Change a version in
`charon.toml` and everything follows. Building builds whatever is missing and
reuses whatever is not.

`libios6compat.a` holds only this port's own stubs. It used to carry copies of
OpenSSL's and libpsl's objects, and because it comes first on the link line
those copies - not the packages - were what the engine actually linked. The
engine now links both packages directly.

`libios6compat.a` - the symbols this OS predates, see
[compatibility.md](compatibility.md) - is this port's own code, built by the
engine's recipe from the `[[static-library]]` block of `charon.toml` before the
engine itself.

`scripts/check-cacert.py` builds nothing: it verifies the trust store the
standalone application carries against the hash this project reviewed, and with
`--upstream` says whether curl serves the same extract today.

## 3. The engine

```sh
charon build
```

`charon.toml` declares the whole build, the way a Gradle build file does, and
Charon writes the recipe from it: that recipe
installs the libraries, writes the CMake toolchain and cache - every path taken
from the dependency graph, the linker from the `ld64` package - and then runs
the steps in the order that fails cheapest first:

1. `scripts/carry-check.py` - the engine tree still holds what this port needs
2. `libios6compat.a`, then the engine through CMake and Ninja
3. WebKitLegacy exports exactly the symbols its export list names
4. `tools/compat-audit.py` - no stub shadows a definition WebKit has
5. `tools/symbol-check.py` - the symbol surface matches `carry-symbols.txt`
6. `platform/` through CMake - the loader, the compat and TLS dylibs and the
   Settings bundle - stripped and signed
7. the frameworks laid out as the iOS 6 system frameworks they replace, beside
   the C++ runtime and everything from step 6, as the whole device filesystem
   tree in `build/system/stage`
8. `dyld-imports-check` from Charon, when the phone's shared cache is
   configured

Everything lands in `build/system`. The `.deb` is a separate step,
described in [the package](#4-the-package). Why each CMake setting has the
value it has is in [engine-configuration.md](engine-configuration.md).

A change to any recipe here or in Charon changes its revision, and
`conan.lock` has to follow in the same commit:

```sh
charon build --lockfile= --update
```

A stale lock does not fail on the machine that made the change - the old
revision is still in its cache and the build quietly uses it - only on a fresh
clone. `.github/workflows/port.yml` is that fresh clone: without the SDK, which
cannot be redistributed, it checks that every Python file compiles, that the
engine at the pinned commit still holds what `carry-manifest.txt` names, that
`conan.lock` resolves against both repositories' recipes, and ICU on the host.

Three things about this build are worth knowing, because they explain choices
that look arbitrary otherwise.

**The engine is built without a class prefix.** The prefix exists so this engine
can sit in a process beside the system one. When a process takes our frameworks
through `DYLD_FRAMEWORK_PATH` the system engine is never loaded, there is
nothing to collide with, and UIKit needs the classes under their real names - it
links `_OBJC_CLASS_$_WebView`, not a prefixed spelling. The recipe therefore
builds the unprefixed engine by default; `charon build --variant prefixed` builds the prefixed
one for the standalone application.

**The recipe arranges that build as the system frameworks a process expects**,
into `build/system/stage/usr/lib/rev-fw` rather than an application bundle,
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
`tools/compat-audit.py` checks for exactly that:

```sh
python3 tools/compat-audit.py --compat build/system/compat/libios6compat.a \
    --engine-build build/system --icu "$CHARON_HOST_ICU"
```

**Every import has to exist on the phone.** The SDK the engine compiles against
is years newer than the system it runs on, so a call can link cleanly against a
function iOS 6 never had. Nothing fails at load: the import is bound lazily, and
the process dies the first time the call is made. A plain `ws://` WebSocket did
exactly that. `dyld-imports-check`, a tool_requires from Charon because
the other port needs it too, compares every non-weak import in the staged tree -
the frameworks, the C++ runtime, the tweak and TLS dylibs and the Settings
bundle - with what the phone's own shared cache exports, and the build runs it
once it knows where a copy of that cache is:

```sh
charon device fetch /System/Library/Caches/com.apple.dyld/dyld_shared_cache_armv7 build/
charon build \
    -c user.apple-ios:dyld_shared_cache="$PWD/build/dyld_shared_cache_armv7"
```

`build/` is reproducible and gitignored.

**A change to a WebCore header means a full build - `charon build`, which builds
everything.** A partial build leaves
WebKit and WebKitLegacy compiled against the old class size, and the result loads
and then behaves wrongly — empty text in the interface, and a silent death with no
crash log. This has cost more than one debugging session.

`charon build --variant prefixed`
builds the same source with the class prefix applied, into
`build/prefixed`, for a build that has to coexist with the system
engine in one process. The shipped build is the unprefixed one; see
[architecture.md](architecture.md#two-webkits-in-one-process).

## 4. The package

```sh
charon package
```

`charon build` has already built everything around the engine - the
`[[device-library]]` blocks of `charon.toml` build `RevSafari.dylib`,
`rev-safari-compat.dylib`, `rev-TLS.dylib` and
`RevPrefs.bundle` - and laid it out with the engine in
`build/system/stage`. `charon package` runs the recipe's
`package()`, which copies that tree into `<package folder>/root` and writes
`<package folder>/deb/space.kern0x1b.rev_<version>_iphoneos-arm.deb` with
charon-apple's `DebianPackage`: `debian-binary`, `control.tar.gz` and
`data.tar.lzma`, the same members `dpkg-deb` writes. To release a new version,
change `version` in `charon.toml` and build. `packaging/` holds only
`packaging/control`, which carries no version of its own, and
`packaging/DEBIAN/postinst`.

One `.deb` carries the loader and its MobileSubstrate filter, the compatibility
and hook dylib, the TLS library, the Settings bundle with its PreferenceLoader
entry, the C++ runtime and the engine frameworks.

Two settings on the `rev-safari-compat` device library in `charon.toml` are not
optional: the compat dylib is
built without `_FORTIFY_SOURCE` and without libc++ (`-nostdlib++`), because the `__*_chk` symbols
are linkage this release never had and the engine carries its own C++ runtime — a
second one in the same process is a crash waiting to happen.

## 5. Onto the device

Copy `device.env.example` to `device.env` and fill in the address and password;
neither is in the repository.

```sh
charon deploy    # engine only: back up, push the staged frameworks, restart Safari
```

For everything else, install the package the way any tweak is installed:

```sh
charon device copy "<package folder>/deb/space.kern0x1b.rev_<version>_iphoneos-arm.deb" /tmp/rev.deb
charon device run 120 "dpkg -i /tmp/rev.deb"
```

## The engine without Safari

`app/rev-webview-host.m` is a plain UIKit view controller around one `WebView`:
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
charon build --variant prefixed
charon run --wait 20
```

The prefixed build ends in `build/prefixed/RevWebViewHost.app`,
the engine and the C++ runtime bundled inside it and its version taken from
`charon.toml`; `charon package --variant prefixed` puts it in
`<package folder>/RevWebViewHost.app`. The runner installs it, opens it through its
`revwebviewhost:` scheme and brings back the log. It needs the device
address in `device.env` at the root of the checkout, as everything that reaches
the phone does.

**As an embedding surface.** Compiled with `-DREV_WEBVIEW_HOST_NO_MAIN` the file
carries no `main()`, and `RevWebViewHostControlling` in
`app/RevWebViewHostEmbedding.h` is the whole interface another application
drives it through — load, back, forward, reload, stop, a content frame, and a
delegate that reports title, progress, URL, scroll offset and failures. That is
the consumer the app-shell cache policy in [network.md](network.md) was written
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
otool -L build/system/stage/usr/lib/rev-safari-compat.dylib
otool -l build/system/stage/Library/MobileSubstrate/DynamicLibraries/RevSafari.dylib | grep LC_ENCRYPTION_INFO
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
screenshots: [`tests/device/run.py`](../tests/device/README.md).

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
link whether or not anything references it. The `openssl` recipe patches
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
- the linker: the `ld64` package from Charon - ld64 956.6 built from
  `cctools-port`, which supports armv7, reads `.tbd` stubs through
  `apple-libtapi`, and does LTO through the same LLVM;
- the SDK: the iOS 16.4 SDK from theos/sdks, which has never depended on
  Xcode.

The `ld64` recipe carries the two snags in building it: `apple-libtapi` calls
`get_darwin_linker_version`, a CMake helper its vendored LLVM does not ship, so
the call is guarded and `HOST_LINK_VERSION` set by hand; and cctools' bundled
`llvm-c/lto.h` wants headers from a newer LLVM, so it is configured against
Homebrew's.

