# How this started

Kept as history, not as documentation: this is the plan and the reasoning from
the first days of the port, in August 2026, when nothing had been built yet. Much
of it was overtaken by what the work found — the base branch changed, the ARMv7
JIT came back, the standalone application gave way to substituting the engine
underneath Mobile Safari. For what the port is today, start with
[architecture.md](architecture.md) and the README.

The stock engine on iOS 6 is WebKit 536 (2012). It cannot render a page written
this decade: the sign-in form of soundcloud.com comes back with zero input
elements in the DOM, because the script that builds it never runs.

The goal is a browser view — one `UIView`, one URL, no chrome — running an
engine new enough to open today's sites on an iPhone 4S.

## Base: current WebKit trunk

The build tracks `WebKit/WebKit` `main`. An earlier attempt used the Safari-603
branch (iOS 10.3, 2017) on the assumption that it was the last WebKit ever built
for 32-bit ARM. That assumption was wrong in a useful way:

- armv7 is still a live target in trunk. What was removed — on 2026-08-01, three
  weeks before this was written — is the ARMv7 **JIT**. The commit says so
  plainly: *"ARMv7 runs on CLoop now."* `Source/JavaScriptCore/assembler/` keeps
  only ARM64, ARM64E, RISCV64 and X86_64, and `ENABLE_JIT` auto-enables on
  X86_64 and ARM64 only. So JavaScript is interpreted on this device.
- Apple's clang 21 still emits armv7 Mach-O and still accepts a 6.0 deployment
  target, so C++23 code compiles for a 2011 phone.
- Trunk's build scripts are Python 3. The 603 branch's are Python 2, and every
  failure in that attempt was a dead stdlib module or a changed built-in, never
  WebKit's own C++.

The 603 checkout stays in the tree as a fallback and as a source of code trunk
has since deleted — the Darwin ARM32 register accessors came from there.

## Prior art on the same device: LightKit

`org.webkit.LightweightBrowser`, armv7, `MinimumOSVersion` 4.3, found already
installed on the target iPhone 4S. No source published. Its binaries answer most
of the open design questions:

- **It is the Cocoa WebKitLegacy port, not WPE.** `WebKitLegacy` links CFNetwork,
  and its Objective-C classes are `LegacyIOSWebView`, `LegacyIOSWAKWindow`,
  `LegacyIOSWebEvent`, `LegacyIOSWAKScrollView` — the ordinary iOS WebKitLegacy
  classes with a prefix applied so they cannot collide with the system WebKit.
  That is the same API `UIWebView` is built on.
- **The engine is recent.** `WebCore` contains `view-transition`, `anchor-name`,
  `@scope`, `:has()`, `subgrid`, `popover`, `corner-shape`, `sibling-index`, CSS
  `@function`, `progress()` and `text-box-trim` — 2025-era features.
- **`libLegacyIOSRuntime.dylib` (31 MB) is a C++ runtime, not an API shim.**
  10 414 exports, 9 048 of them mangled C++: modern libc++ (`std::__1`),
  libc++abi and ICU 74, depending on nothing but `libSystem` and `libobjc`.
  iOS 6 ships a 2012 libc++ and an ICU far older than WebKit's minimum, so a
  current WebKit has to carry its own.
- **`LegacyIOSModernTLSURLProtocol`** — an `NSURLProtocol` subclass implementing
  modern TLS, because CFNetwork on iOS 6 cannot negotiate with today's servers.

Its full system dependency list, all present in iOS 6: UIKit, CoreGraphics,
QuartzCore, CoreFoundation, Foundation, CFNetwork, AVFoundation, CoreMedia,
CoreAudio, AudioToolbox, Accelerate, IOKit, `libxml2`, `libsqlite3`, `libz`,
`libAccessibility`, `libgcc_s.1`.

## State

Built for armv7 against the iPhoneOS 10.3 SDK with a 6.0 deployment target:

| Part | Status |
|---|---|
| `libbmalloc.a` | builds |
| `libWTF.a` | builds — 174 files, no C++ errors |
| `libJavaScriptCore.a` | builds — 23 MB, CLoop interpreter |
| ICU 74.2 (`libicuuc`, `libicui18n`, `libicudata`) | builds, `--disable-renaming` |
| libc++ 21 / libc++abi for armv7 | builds |
| `jsc` shell | **runs on the iPhone 4S** |
| WebCore, WebKitLegacy | building |

### Milestone 1 result

`jsc` from trunk runs on the device, and it is a current engine, not a subset:

```
private field: 5                                  // #x
optional chain: ok                                // ?. and ??
Object.groupBy: {"odd":[1,3],"even":[2,4]}        // ES2024
Array.fromAsync: function                          // ES2024
RegExp v flag: true                                // ES2024
Temporal: object                                   // ES2026
```

First throughput numbers. The comparison mixes two effects — a 2011 CPU and the
absence of a JIT — so treat it as an order of magnitude, not a JIT penalty:

| | iPhone 4S, CLoop | Mac, JIT |
|---|---|---|
| `fib(24)` | 97 ms | 3 ms |
| 2 M iteration loop | 2128 ms | 7 ms |

Roughly a million simple JS operations per second.

### The JIT question

The ARMv7 JIT was not removed because it broke. Between 2026-03-08 and
2026-03-15 WebKit started forcing it off for every 32-bit build:

```
#if USE(JSVALUE32_64)
#undef ENABLE_JIT
#define ENABLE_JIT 0
```

The now-orphaned assembler was deleted on 2026-08-01 (`857bd4334690`,
*"ARMv7 runs on CLoop now"*). So a checkout from before mid-March 2026 still has
a working ARMv7 JIT — five months of engine work traded for a large constant
factor on JavaScript. Worth measuring once there is a page to measure.

The second condition is executable memory. The device is jailbroken and does not
enforce code signing, so `mmap` with `PROT_EXEC` should work — but that has to be
tested, not assumed.

## Build environment

C++23 needs a libc++ newer than anything in the iOS 10.3 SDK, so headers come
from the current Xcode SDK while the C library and frameworks come from the old
one:

```
-target armv7-apple-ios6.0
-isysroot .../iPhoneOS10.3.sdk
-nostdinc++ -isystem .../iPhoneOS26.5.sdk/usr/include/c++/v1
-D_LIBCPP_DISABLE_AVAILABILITY
```

Headers are enough to compile. The **runtime** is a separate problem, and the
one LightKit solved by bundling its own — see milestone 2.

Two settings are not obvious:

- **`-fdwarf-exceptions`.** clang defaults armv7 to setjmp/longjmp exceptions and
  emits references to `__gxx_personality_sj0`. iOS ships only the DWARF
  personality, `__gxx_personality_v0`.
- **ICU `--disable-renaming`.** WebKit defines `U_DISABLE_RENAMING=1` on Apple
  platforms because Apple's `libicucore` exports unsuffixed names. A stock ICU
  build exports `u_charDirection_74`, so it must be built the same way.

`build-icu.sh` builds ICU twice: once for this Mac, because ICU needs its own
tools to generate its data, and once for the device. `build-libcxx.sh` builds
libc++ and libc++abi from `llvmorg-21.1.0`, matching the header version.

## What the port had to change outside its own guards

Six upstream files, thirty added lines, now carried on the engine branch itself:

- `Source/bmalloc/bmalloc/bmalloc.h` — `aligned_alloc` is C11 and arrived in
  iOS 11; `posix_memalign` has the same contract for these callers
- `Source/JavaScriptCore/runtime/MachineContext.h` — restore the Darwin ARM32
  register accessors (`__r[7]` as frame pointer), deleted along with the JIT
- `Source/WTF/wtf/PlatformHave.h` — no readline in the iOS SDK
- `Source/WTF/wtf/PlatformJSCOnly.cmake` — run `mig` against the macOS SDK; the
  iOS SDK ships no `mach/*.defs`
- `Source/WTF/wtf/darwin/OSLogPrintStream.mm` — `os_log` is iOS 10; write to
  stderr
- `Source/cmake/WebKitMacros.cmake` — create the destination directory before
  symlinking forwarding headers

## Milestones

1. **JavaScriptCore builds for armv7 and runs a script on the device.** The
   smallest thing that proves the toolchain. The libraries build; the shell is
   blocked on milestone 2.
2. **A C++ runtime that works on iOS 6.** libc++ and libc++abi built for armv7
   and linked in, as LightKit does.
3. **WebCore and WebKitLegacy build**, with the `LegacyIOS` symbol prefix so they
   coexist with the system WebKit.
4. **An app with a single view showing one URL.**
5. **Modern TLS**, as an `NSURLProtocol`.
6. **Measurements**: memory, first paint, scrolling. 512 MB of RAM and an
   interpreter-only JavaScript engine are the two numbers that decide whether
   this is usable or merely impressive.
