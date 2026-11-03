# Carrying this port against a moving engine

The engine under this port is not ours, and the platform it targets was deleted
from it: upstream removed the ARMv7 JIT on 2026-08-01 and, with it, the whole
32-bit JSValue world — `main` today has no `LowLevelInterpreter32_64.asm`, no
`ARMv7Assembler.h`, and no `USE(JSVALUE32_64)` left in `Source/JavaScriptCore/runtime`.

Two consequences decide everything below. The port has to **own** that code
rather than inherit it, and it has to **find out early** when an upstream change
breaks it, because nothing upstream will ever tell us.

## The shape of the carry

| | |
| --- | --- |
| `packages/w/webkit/xmake.lua` | the base: one commit of upstream `WebKit/WebKit` `main`, fetched by hash |
| `packages/w/webkit/patches/` | the product: this port as an ordered series of patches, one per concern, each explaining in its message what it changes and why |
| the recipe's checksums | one sha256 per patch, so the series that builds is the series that was reviewed |

There is no fork to keep in step and no merge commit to read: base plus series is the
whole engine, and applying the series to its base reproduces, file for file, the tree
the fork's `main` carried when the series was cut.

Two rules, both borrowed from projects that do this at scale:

- **Upstream first for anything generic.** A bug we fix in OpenSSL paths, in the
  Cairo gamma handling, in ICU's grapheme iterator is not port-specific, and
  every such fix we send upstream is one we stop carrying. Android's kernel team
  and Asahi both converged on this for the same reason.
- **Every carried change justifies itself in its commit message.** Electron's
  rule for its Chromium patches, and it is the only thing that keeps a carry
  reviewable years later.

## What "owning" means: the carry manifest

An upstream merge can break this port in three ways, and only one of them is
loud:

1. **It stops compiling.** Loud, and the build catches it.
2. **Something we carry silently disappears** — a file upstream deleted again, a
   feature flag that flipped, a symbol that stopped being exported. Nothing
   catches this until the device behaves strangely, or a page renders blank.
3. **Behaviour changes** under the same code. Only tests catch it.

For (2) the answer is a declarative manifest, checked before anything is built:

```sh
./xmakew l -P . frameworks/WebKit/tools/carry_check.lua [--tree DIR]   # reads carry-manifest.txt, fails with a list
./xmakew l -P . frameworks/WebKit/tools/carry_check.lua --paths        # the engine paths it reads, for a sparse checkout
```

Every engine build runs the same check on the patched tree before it compiles anything.

It found its first real problem on the day it was written - an assertion that
named the wrong header for `-[WAKWindow _windowRef]`, the accessor UIKit uses to
get its window and the last thing that had to be restored before the engine
would load at all.

What it asserts about a merged tree:

- **Files that must exist**, because the port cannot run without them:
  `assembler/{ARMv7Assembler,ARMv7Registers,MacroAssemblerARMv7}.h`,
  `MacroAssemblerARMv7.cpp`, `llint/LowLevelInterpreter32_64.asm`,
  `dfg/DFGSpeculativeJIT32_64.cpp`, `jit/JITOpcodes32_64.cpp`,
  `jit/CallFrameShuffler32_64.cpp`, `offlineasm/arm.rb`, the `bmalloc` iOS 6
  variant, the WebKitLegacy tree, the ANGLE EAGL backend this port wrote.
- **Build facts that must hold**: `ENABLE_JIT` on and `ENABLE_C_LOOP` off for
  armv7, `USE(JSVALUE32_64)` reached by the armv7 configuration, the CMake
  entries that name the files above.
- **The symbol surface**, in `carry-symbols.txt` and checked by
  `src/modules/symbols.lua` as a step of every engine build: every symbol the three
  frameworks leave undefined - 6109 of them - and every Objective-C class they
  export by name. A *new* undefined symbol is the important one: it means an
  upstream change reached for API this system may not have, and dyld kills the
  process at load with no crash log. A lost exported class is the same death
  from the other side, since UIKit and Safari link `WebView` and its siblings by
  name.
- **The guard census**: how many files carry `WEBKIT_IOS6`, by area. A merge that
  reverts one of our hunks usually shows up here first — the count drops in one
  directory.

The manifest is the cheapest tier by an order of magnitude: it reads the tree,
needs no compiler and no phone, and it is the thing that answers "what did this
merge quietly take away from us".

### When the symbol gate fires

It is a question, not a verdict. The gate prints every new undefined import, and
judges each one against the iOS 6.0 armv7 cache (`xmake firmware --arch=armv7 fetch 6.0`
fetches it): an import is accepted when the library its binary names for it, by the
two-level ordinal, exports the symbol in that cache, and rejected with the reason otherwise.
A flat-namespace import, an ordinal that names no library, or a library the cache does not
hold is rejected too. Only a rejected import needs a decision: a device check that shows
the device resolves it, then `tools/symbol_check.lua --pin` so the baseline records it.
The judgement is `dyld.import_verdicts` in `toolchain/modules/apple/dyld.lua`, and
`./xmakew l frameworks/WebKit/tests/gate/symbols_test.lua` tests it on fixtures
(it needs `REVENANT_LD64` set to the `bin/ld` of the `revenant@ld64` package).

### The C++ library

The engine binds its C++ library as `@rpath/libc++.1.dylib`, while the iOS 6.0 cache holds
that library as `/usr/lib/libc++.1.dylib`. The gate therefore judges an import bound to the
`@rpath` name against the cache's `libc++.1` (`LIBRARY_ALIASES` in `dyld.lua`). No other
`@rpath` name is remapped, and an `@rpath` library the cache does not hold is still rejected.
This is a judgment rule, not a device check. On the phone the name resolves to the carried
`librev-c++` or to the system `libc++.1`; the cache's library and the `librev-c++` the port
builds both export the `basic_string` members the engine imports, and the fixture test
covers an exported, a missing and an unheld `@rpath` import. The rule holds while
`librev-c++` exports what the cache's `libc++.1` does for the engine's imports. For a new
C++ import, check it with `nm -gU` on the `librev-c++` build as well before pinning it.

The first time this ran in anger, on 2026-09-11, it was the second case: an
ANGLE roll had started calling `crc32_z`, which zlib gained in 1.2.9 and this
system's 1.2.5 does not have. Nothing in a build would have said so. On the
device it is a refusal at load, with no crash log and no output - the failure
this port has spent the most time chasing blind.

## The test pyramid, and what needs the phone

| Tier | Needs | Cost | What it catches |
| --- | --- | --- | --- |
| 1. Carry manifest | nothing | seconds | our code deleted, a flag flipped, a guard reverted |
| 2. Host checks | Mac | seconds | ICU data damage, the CA bundle's pin, generated encoding lists |
| 3. armv7 build, then the symbol check | Mac | minutes | every API change upstream made to code we touch, and any new dependency on API iOS 6 may not have |
| 4. Device suite | the iPhone | minutes | UIKit, CoreText, CoreGraphics, the GPU, and whether pages actually paint |
| 5. Device long runs | the iPhone | tens of minutes | WebGL conformance, memory bands over cold launches, a crash sweep |

Tiers 1 to 3 are the answer to the question of testing without a phone. The
32-bit JSValue representation and the ARMv7 JIT - this port's largest carry -
have no host tier of their own: a JSCOnly build for 32-bit ARM Linux was tried
and dropped, because the binary aborts during `JSGlobalObject::init` under
emulation and a tier that cannot run its own suites is not coverage.

What the phone remains irreplaceable for is everything the manifest cannot
describe and a Linux container does not have: a 2012 UIKit, this CoreText, this
CoreGraphics, the PowerVR driver, jetsam, and the question of whether a real
page paints. That is what `tests/device/` measures, and why it reports numbers
rather than screenshots.

## How an update actually runs

Moving the base is work in a scratch clone of WebKit, never in the package cache:

```sh
git clone --filter=blob:none https://github.com/WebKit/WebKit.git webkit && cd webkit
git switch -c series <new base commit>
git am <revenant>/packages/w/webkit/patches/*.patch
git format-patch -N -o <revenant>/packages/w/webkit/patches <new base>..series
```

In order, stopping at the first failure that matters:

1. Apply the series onto the new base, one patch at a time, so each conflict lands in
   the concern its patch is about.
2. Re-export the series, and put the new base commit and every patch's sha256 in the
   recipe.
3. `tools/carry_check.lua` on the rebased tree — before a single file is compiled.
4. `tools/port_delta.lua` and `tools/carry_audit.lua` against the old tree — the delta,
   the guard census, and the files whose port markers thinned out in the move.
5. The armv7 build, `./xmakew -P .`, which runs the carry check, the export check, the
   compat audit and the symbol check against the pin itself.
6. Host tests.
7. Deploy, then the device suite — if the phone answers. If it does not, the move is
   unverified and must not be shipped.

Only a series that reached the end green replaces the one in the recipe. The scratch
branch is allowed to be red for as long as it takes — that is what it is for.

### Cadence

- **Per upstream release or release candidate**: move the base, tiers 1 to 4. Frequent
  small moves are cheaper than rare large ones, and the kernel's own guidance
  for downstream trees says the same: move at release points, not continuously,
  and keep each patch narrow so it moves independently.
- **Weekly**: upstream's security fixes picked onto the series, then the full pyramid,
  with the device.
- **Before anything is published**: tier 5 as well.

How far the series is from upstream today can be measured without moving it: applying
each patch in turn to a tree of the current `main`, with `git apply --3way`, counts the
files each patch would conflict in. Against `main` of 2026-10-19 the series of 26 patches,
measured before its configure-without-Python patch was dropped, conflicts in 261 files, in
19 of the patches; WebCore above the platform layer (patch 11,
86 files) and the WebKit1 API iOS links (patch 22, 48 files) are half of it.

Nothing that moves the base may push on its own: a series nobody has read is not a
release, and the only thing that makes it shippable is a person looking at the device.

## What tracking `main` costs today, measured

`git merge-tree` computes the merge without touching a working tree, so the
question can be answered before anyone commits to it. Merging this port's `main`
with upstream's, on 2026-09-11:

```
337 files conflict
  150  Source/ThirdParty      ANGLE rolled forward on trunk
   99  Source/WebCore
   30  Source/JavaScriptCore
   16  Source/WebKit
   15  Source/WTF
```

Of those 337, **143 are files this port changed**. The rest is the year of
divergence between the 2.54 branch and trunk, which any base change would have
to absorb once and then never again.

## What tracking `main` turned out to need

`main` has no 32-bit JSValue, and the plan here used to be that basing on it
required a 64-bit NaN-boxed JSValue on ARMv7 first. That proved wrong in
practice: the 32-bit world is a set of files and build entries, and carrying them
onto trunk is mechanical enough that the branch now runs on the phone. What the
merge really costs is written up in
[core-update.md](../../explanation/webkit/core-update.md#the-trunk-branch-runs-2026-09-12), together with
the five bugs that only the device found.

That is not a dependency on someone's goodwill: the base is one commit named in the
recipe, and every piece of the port, including the 32-bit engine world, is a patch in
this repository. The base commit is the one thing fetched from upstream.

## Order of work

1. **Ancestry.** A branch from the exact upstream commit this snapshot is based
   on, with the port replayed on top, verified by an empty `git diff` against the
   frozen graft. Then `main` is ours, `upstream` is a remote, and merges are
   merges.
2. **The manifest and its check.** Cheapest tier, largest return.
3. **Topic branches.** Split the carry by concern so a merge conflict lands in
   one subject at a time. Done as the patch series: the fork's 176 commits and its
   merge of the 2.54 branch, grouped into 24 patches that applied to upstream
   `c70a794b03` give the fork's tree exactly; then this port's own comments were
   taken out of them and one build patch added, keeping the configured compiler. The
   build runs WebKit's own Python generators as WebKit ships them, through the
   `Python_EXECUTABLE` the engine passes to CMake.
4. **32-bit JSC coverage on the host.** The container, the build, the suites.
5. **The integration branch against `main`**, to measure the real cost and to
   host the 64-bit JSValue work.
6. **Guards.** Of 1309 changed files under `Source`, 375 announce themselves with
   `WEBKIT_IOS6` and 934 do not. Every file moved into that column makes every
   future merge cheaper; this is the work that decides whether tracking `main`
   is sustainable.
