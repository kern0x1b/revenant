# Keeping the engine current

The engine is a real fork. `main` in this fork is upstream's history with this
port's commits on top of `1b78c03f880e`, so upstream is an ancestor and a merge
is a merge. It was a graft until 2026-09-11 - a snapshot with no shared
ancestry, updated by applying other people's diffs - and
[maintaining.md](maintaining.md) is what that fork is carried by now.

How far the port has drifted is still a question about content rather than about
the log, and `scripts/port-delta.py` answers it. Today, against
`origin/webkitglib/2.54`:

```
1396 files changed, 52650 insertions(+), 9987 deletions(-)

  Source/WebCore          585 files  +24105  -5358
  Source/WebKitLegacy     389 files  +5181   -313
  Source/JavaScriptCore   169 files  +14478  -1107
  Source/bmalloc           56 files  +5392   -13
  Source/WTF               56 files  +1851   -328
```

## How far behind the snapshot is

`scripts/port-delta.py --freshness` answers that from content rather than dates,
because content is what the question is really about: for each commit on the upstream branch
it takes a line that commit added and looks for it in our tree, and the first
one we already carry is where the snapshot sits. Today:

```
branch tip: 2026-09-03  Cherry-pick 305413.1005@safari-7624.5.1.10-branch
we carry:   2026-09-03  Cherry-pick 305413.1005@safari-7624.5.1.10-branch
behind by:  0 commits
```

So the engine is not on an old WebKit: it is on the current stable series,
version 626.1.1, level with that branch's tip. The series is alive -
`webkitglib/2.54` last moved on 2026-09-03 and `2.52` on 2026-09-04, both taking
cherry-picks from Safari's branch, while `2.50` stopped in March.

Distance from `main` cannot be answered from this clone: `main` is fetched as a
single commit, so its history is not here. The relationship is the usual one -
the 2.54 branch is cut from main and receives security and stability picks,
while main is where new work lands.

## What that delta actually is

Two thirds of it is not port-specific logic:

- **JavaScriptCore, +14.5k across 174 files** — but two thirds of that is four
  files: the ARMv7 disassembler, which the base branch does not build, and the
  unexported-libc++ list, together 9321 lines that move only when the toolchain
  does. The ARMv7 JIT itself is *not* in this delta: `webkitglib/2.54` still
  ships it, wired into `CMakeLists.txt`, and the port builds with
  `ENABLE_JIT=ON`, `ENABLE_DFG_JIT=ON`, `ENABLE_C_LOOP=OFF`. What is left, some
  five thousand lines, is this port's own tuning of the collector, the inline
  caches, the code cache and the ARMv7 macro assembler.
- **WebKitLegacy, +5.3k across 389 files.** The WebKit1 API, which upstream keeps
  but no longer builds for iOS. Mostly reinstatement and build plumbing.
- **bmalloc, 50 new files.** The allocator's iOS 6 variant, self-contained.

The part that has to be understood on every update is the rest: the changes that
adapt current WebKit to a 2012 system.

## Why changing base is realistic

Of the 1309 files changed under `Source`, **375 carry the `WEBKIT_IOS6` guard**
and announce themselves. Those hunks say
what they are and where they belong, and they can be replayed onto a newer tree
by matching the guard rather than by matching context lines.

**934 do not**, and they are where the cost is. By area:

```
Source/WebKitLegacy   373
Source/WebCore        328
Source/JavaScriptCore 106
Source/bmalloc         56
```

The WebKitLegacy and bmalloc ones are wholesale reinstatement, so they move as
files rather than as hunks. The WebCore and JavaScriptCore ones - some 440 files -
are the real work of an update.

## Two kinds of update

They cost very different things.

**Inside the series** — `webkitglib/2.54` taking security and stability picks
from Safari's branch. With ancestry this is an ordinary merge:

```sh
git -C webkit-254 fetch upstream 'refs/heads/webkitglib/2.54:refs/remotes/upstream/webkitglib/2.54'
git -C webkit-254 merge upstream/webkitglib/2.54
```

Conflicts land only where a pick touches a file this port also changed, which
`scripts/port-delta.py` lists, and `rerere.enabled` means a resolution is only
made once. Then the carry check, the build, and `tests/device/run.py`.

The last update done the old way, on 2026-09-10, took the branch's five newest
picks as a diff: none touched a port-changed file, the engine rebuilt whole
because one of them changed a WebCore base class, and the suite stayed at 55 of
55.

**Changing series** — 2.54 to 2.56 or later, or to `main`. That is the work
below, and it is the one that also has to carry the ARMv7 JIT forward.

## The trunk attempt, 2026-09-11

Tried for real, on a branch, to see what it costs rather than to guess. What the
merge with `upstream/main` produced, and what came out of working through it:

**202 conflicted paths.** 179 both-modified, 16 files this port changed that
upstream deleted, 6 added on both sides, 1 the other way round. Of those, 21
were upstream against upstream - the series' own cherry-picks against trunk's
evolution, in files this port never touched - and taking trunk's side is right
for all of them. 35 more are in code this port does not build. That leaves
**about 145 files that have to be read**, 199 conflict hunks, and roughly half
carry a `WEBKIT_IOS6` guard on one side.

**476 files the merge deleted without conflicting at all.** Most are upstream's
own removals over 3222 commits, but five were load-bearing here - the 32-bit
LLInt, the ARMv7 registers and macro assembler, two 32-bit JIT sources - and
nothing in git said so, because this port had not touched them since the branch
point. `scripts/carry-check.py` named all five in under a second. That is the
clearest argument for the manifest that exists.

**Two build systems have to be carried, not merged.** Upstream removed the iOS
CMake port outright: `Source/cmake/OptionsIOS.cmake` and every
`PlatformIOS.cmake` are gone from trunk, so they become this port's files rather
than edits to upstream's. The offlineasm backend list and the JavaScriptCore
source list lost their ARMv7 entries the same silent way the sources did.

**Preferences changed shape.** `UnifiedWebPreferences.yaml` is validated far
more strictly on trunk: a frontend that only carries a default must be written
as a scalar, frontends must appear in the order WebKitLegacy, WebKit, WebCore,
and a value equal to the shared default has to be left out. The port's 33
enabled features transplant cleanly once written that way, and the list of
exactly which 33 comes out of `git diff` rather than memory.

Where it stopped: JavaScriptCore and WTF are fully merged, 68 files in WebCore
and below are not, and the 32-bit JavaScriptCore build against trunk gets as far
as compiling WTF. `JSCJSValue.h` needs its 32-bit half re-threaded into a
conditional chain trunk rewrote around it - that one is real work, not a
mechanical merge.

The branch is `trunk-integration` in the engine fork, and `git rerere` recorded
183 resolutions along the way, so redoing the merge replays them instead of
asking again.

## The trunk branch runs, 2026-09-12

`trunk-integration` is no longer a measurement. Built for armv7 against
`upstream/main` it loads in Mobile Safari, renders, runs JavaScript through the
LLInt, the baseline JIT and the DFG, and passes the device suite 55 of 55. The
32-bit engine world was carried, not replaced: the JSValue representation work
described in [armv7-jit.md](armv7-jit.md) turned out not to be a precondition.

What actually had to be fixed after the merge compiled, in the order the phone
found them:

- **The LLInt's tier-up path popped one register.** `macro prologue` kept only
  the x86 spelling, `pop cfr`. ARMv7 pushes `lr` and `cfr` separately, so every
  frame the interpreter handed to compiled code sat four bytes low and the
  CodeBlock was read out of the wrong half of its slot. Everything above the
  interpreter crashed until both pops were restored.
- **A duplicated lock deadlocked the first property store.** The carry left a
  `GCSafeConcurrentJSLocker` around upstream's own `ConcurrentJSLocker` on the
  same CodeBlock lock in `slow_path_put_by_id`. `o.a = 1` parked the main thread
  forever. A trace of `WTF::Lock::lockSlow` printing the lock address found it in
  one run: it fired exactly once, at `CodeBlock+0xc`.
- **Linear sRGB stopped being distinguishable from sRGB.** Trunk renamed
  `DestinationColorSpace` to `ColorSpace` and dropped the port's linear flag. iOS
  6 has no linear color space, so the port maps it onto device RGB and
  `CGColorSpaceEqualToColorSpace` then calls the two spaces equal, which silently
  removed both filter conversions.
- **WebGL required a framebuffer blit the driver does not have.** Upstream now
  demands `GL_NV_framebuffer_blit` at context creation; the 4S exposes neither it
  nor `GL_ANGLE_framebuffer_blit`, so every `getContext("webgl")` returned null.
  The requirement is soft again, surface copies fall back to reading the pixels
  back, and `preserveDrawingBuffer` copies with `CopyTexSubImage2D`.
- **Three port adaptations came back from files taken wholesale from trunk.**
  Touches stopped producing pointer events, which is exactly the bug that once
  made media controls untappable; the layout viewport override and the
  fixed-position rect were no longer refreshed at layout; and the inspector-only
  quad collection ran on every layout again.

- **A dropped node child made `for await` crash once it tiered up.** The merge
  lost the third child of `EnqueueAsyncGeneratorDriver`, so the DFG read the
  resume value from an operand whose edge did not exist. On 32-bit that
  operand's register pair is left uninitialized by the constructor's early
  return, so the call marshalled two random registers: a `for await` loop died
  with SIGILL, SIGSEGV or SIGBUS about two runs in five. `JSC_useConcurrentGC=false`
  made it deterministic, which is what made it findable at all.

- **Zeroing a butterfly range does not empty it on 32-bit.** Upstream's fast
  path for shrinking `length` and for `splice` clears contiguous slots with
  `gcSafeZeroMemory`, which is only the empty value where a JSValue is 64 bits
  wide. Here the tag word has to say empty, so `a[2] = "x"; a.length = 1` left
  `2 in a` answering true. The whole class is findable with `grep
  gcSafeZeroMemory`: wherever the fork has a `.clear()` loop and this tree has a
  memset, it is the same bug. `JSTests/es6` catches it in one run - 595 of 605
  pass now, and the ten that do not are the ten `es6.yaml` itself marks as
  expected failures.

Running JSC's own `JSTests/stress` on the phone is what caught that one: 760
files, 16 of them crashing, all in the same feature. The suite is not wired into
a runner here - `for f in *.js; do jsc $f; echo $?; done` with
`JSC_useDollarVM=true` is enough, because what is being asked is whether the
engine takes a signal, not whether each test's assertions hold.

Measured against the shipping fork on the same pages, the trunk engine is not a
regression: Safari's dirty memory is 17.9 MB against 19.5 MB and resident 143 MB
against 156 MB, WebGL presents at 28-30 fps in both, and the conformance subsets
that are red are red identically on both, for driver reasons documented in
[webgl.md](webgl.md).

What the port weighs against trunk, which is the after picture the procedure
below asks for:

```
port delta against upstream/main
 1640 files changed, 95944 insertions(+), 21215 deletions(-)

  Source/WebCore          596 files  +23884  -3548
  Source/JavaScriptCore   490 files  +55639  -16898
  Source/WebKitLegacy     390 files  +6336   -318
  Source/WTF               63 files  +2114   -298
  Source/bmalloc           56 files  +5504   -87
```

JavaScriptCore dominates it now because trunk deleted the 32-bit engine and this
branch carries it: the ARMv7 assembler and disassembler, the 32-bit tiers, the
32-bit LLInt and the build entries that name them.

## Open on trunk, found by the suite and not yet chased

`JSTests/stress` run from the phone left a short list that was not explained
yet, written down here rather than carried in someone's head. All of it except
the varargs miscompilation is closed - see "All 5725 of JSTests/stress, twice"
below - and the list is kept because how it was read is the part worth reusing:

- `class-syntax-double-constructor.js`,
  `compiler-thread-should-not-ref-identifiers.js`, `create-promise.js`,
  `derived-promise-constructor-inlined.js`, `date-get-utc-seconds-jit.js`,
  `data-view-byte-length-oob-exit.js`, `compare-bigint-with-string.js` and
  `constant-folding-phase-insert-check-handle-varargs.js` take a signal as well.
  None of them is triaged yet; the first question for each is whether the
  shipping fork does the same, because the answer decides whether it is this
  merge or an older 32-bit hole.
- Tests marked `memoryHog!` and the OOM tests are killed by jetsam here, which
  is the phone being a phone rather than a finding.
- `create-promise.js` fails with a wrong value rather than a signal, and it is
  **not** a graft regression: the shipping fork's engine fails the same test in
  the same way. Twenty lines reproduce it:

  ```js
  class Base { constructor(cb) { this.y = 2; cb(); } }
  class Derived extends Base { }
  for (var i = 0; i < 20000; ++i) var b = new Base(function(){});
  for (var i = 0; i < 20000; ++i) var d = new Derived(function(){});
  for (var i = 0; i < 20000; ++i) var b2 = new Base(function(){});
  for (var i = 0; i < 20000; ++i) {
      var d2 = new Derived(function(){});
      if (typeof d2 !== "object") print("BAD " + describe(d2));
  }
  ```

  The last loop prints six bad values and then recovers. What lands in `d2` is
  the constructed object with its two halves exchanged: `describe` reads it as
  the double `0x04A07C60FFFFFFFB`, whose low word is `CellTag` and whose high
  word is the cell pointer. That also explains the shape of the original
  failure - `promise.__proto__` comes back as `Number.prototype`, because the
  value really is a double by then.

  What it needs is **varargs inlining**: `JSC_maximumVarargsForInlining=0` is
  clean, and so is `maximumInliningDepth=1`. It is not about constructors -
  `f(...args)` returns a bad value the same way - and not about the implicit
  constructor, which only looked special because a derived class that declares
  none gets `super(...args)`. It is not the 32-bit store protocol either:
  forcing the plain store in `storeAndFence32` changes nothing, and the
  protocol with the concurrent compiler off is clean. `operationLoadVarargs`
  receives its arguments correctly, so the marshalling into it is not where it
  goes wrong. The DFG's own assertions and graph validation stay quiet.

  Narrowed further, with the option forced back on: the callee has to **call
  its own argument** (`function callee(cb) { cb(); return {y: 2}; }` fails, the
  same callee without `cb()` does not, and calling a named global function
  instead of the argument does not), the result has to be a **cell** (returning
  a number is clean), and the function that makes the spread call has to be
  **DFG-compiled** - `noDFG(spreadCall)` is clean while `noInline(spreadCall)`
  is not, so it is that function's own code that is wrong, not its caller's.
  `f.apply(null, args)` fails the same way. Its `Return` looks right in the
  disassembly: the object is in r0 from its allocation and the return writes
  `mvn r1, #4`, which is CellTag, so what reaches the caller should be a cell -
  and what the caller reads is CellTag in r0 and the pointer in r1, the two
  exchanged.

  `JSC_maximumVarargsForInlining` is 0 by default on 32-bit as of
  `899f706c81bf`, so a spread call is no longer inlined here. That is not a
  fix; it turns a wrong value into a missed optimization, and setting the
  option back to 100 brings the repro straight back for whoever chases the
  miscompilation. It costs nothing measurable: a spread call in a loop of
  300000 takes 301 ms with the inlining off, and with it forced on the same
  benchmark does not finish in two minutes, because the speculation on that
  wrong value fails over and over.

## The collector crash was the interpreter's registers, 2026-09-13

`const-tdz.js`, `const-semantics.js` and
`codeblock-should-clear-watchpoints-on-destruction.js` failed on every run
since the graft, always as a collector complaint about a `JSCallee::m_scope`
pointing at a cell that was already on a free list. None of the obvious
suspects held up under measurement: not the JIT, not any collection mode, not
the port's block pool, not the heap allocator files.

The cause was two macros in `LowLevelInterpreter.asm`,
`copyCalleeSavesToBuffer` and `restoreCalleeSavesFromBuffer`, which had lost
their ARMv7 arms and so stored and restored nothing here. That buffer is the
one an entry frame keeps for the registers the JIT ABI treats as callee-saved
while the interpreter keeps them live across a frame: on ARMv7 r10 holds the
metadata table and r11 the bytecode pointer. Unwinding an exception out of
JavaScript therefore handed both back to C++ still holding interpreter state.
`Interpreter::executeEval` keeps its `JSCallee` in exactly such a register
across the VM entry, and assigning to a `const` inside `eval` throws, so the
`callee->setScope(vm, nullptr)` that follows the entry wrote a zero four bytes
into whatever r11 happened to point at. The same gap kept those registers out
of the buffer the collector scans conservatively, which is the other half of
why live cells were being collected.

The technique that found it generalises to any "something writes here and we
do not know who". Give the victim its own pages and take write permission
away: an `InstructionStreamBufferMalloc` that mmaps page-granular blocks, and
an `mprotect(PROT_READ)` right after `UnlinkedCodeBlockGenerator::finalize`.
Install a SIGBUS/SIGSEGV handler that prints pc, lr and the interesting
registers with `write(2)` - not `dataLog`, which is not safe in a handler -
and resolves them with `dladdr`. Stage that engine **unstripped**, or `dladdr`
names the wrong symbol. Then read the faulting instruction out of the local
binary with `otool -tv`: here it was `str.w r2, [r11, #0x10]`, and `0x10` is
where `JSCallee::m_scope` sits.

One thing that does not work, and cost an hour: reading r10 and r11 from C++
with inline asm on either side of the call. The compiler is free to keep its
own values there, so "before differs from after" proves nothing. Only the
fault is evidence.

Five more ARMv7 arms were missing in the same file and are restored with it:
the checkpoint OSR exit and the array-sort comparator return call C functions
whose second argument is an `EncodedJSValue`, which this ABI passes in an
even-aligned register pair rather than the next register; the tier-up call in
the prologue happens before sp is set from the CodeBlock and needs the stack
realigned around it; the stack-alignment assertion cannot use sp as the source
of a logical operation; and `probe` has two callee-save registers here, not
ten.

## The 32-bit engine can now be built with assertions

Upstream has no 32-bit bots any more, so the invariants JavaScriptCore checks
in an assertion build have not been run against a 32-bit engine in years. Three
ARMv7 facts had to be stated before such a build would start, and they are in
`867f5bc0f811`: the opcode id that sits ahead of an LLInt label must be read
from the untagged address, since a Thumb code pointer carries its low bit set;
unaligned halfword loads are allowed on ARMv7, so the pointer-alignment
assertion that guards older ARM does not apply here; and the LLInt's own
assertions do not fit in the ARMv7 register budget, so offlineasm keeps them
off. The same commit carries a fix that assertion build found immediately: the
32-bit DFG compiled `CheckPrivateBrand` with a `JSValueOperand` on an edge the
fixup phase now fixes to `CellUse`, where the 64-bit path and the 32-bit
`SetPrivateBrand` both use a `SpeculateCellOperand`.

Configure it by cloning the shipping build's cache with `ENABLE_ASSERTS=ON` and
`-DENABLE_LLINT_EMBEDDED_OPCODE_ID=0`; the second flag is still needed because
reading the embedded id back out of a Thumb label does not work yet.

## What is still not on trunk, and why

277 files under `Source/JavaScriptCore` and `Source/WTF` are still byte-for-byte
the 2023 base: the port never touched them, and the merge never moved them
forward either. They are found by comparing each file against the fork's base
commit rather than against the fork tip, because a file the port restored to its
old content looks untouched to any other test.

Taking upstream's version of all 277 was tried and reverted the same day. The
files do not move independently: upstream's `AirOpcode.opcodes` needs upstream's
`opcode_generator.rb` (the old one has no `x86` architecture prefix any more),
upstream's Yarr interpreter needs upstream's whole Yarr family down to
`ByteTerm`, and several of the newer files drop the ARMv7 case this port lives
on - `MaxFrameExtentForSlowPathCall.h` has no `CPU(ARM_THUMB2)` value in trunk at
all. What that pass actually needs is one directory at a time with a build and
the device suite after each, not a single sweep; the sweep is what this note
exists to prevent someone repeating.

Sorting the 277 by whether their diff against trunk mentions 32-bit at all
splits them almost in half: 134 read as pure upstream evolution and 143 touch
`USE(JSVALUE32_64)`, `CPU(ARM_THUMB2)` or the port's own marker. The clean half
is not automatically takeable either, and the first three attempts say what the
work actually is:

- `StackBounds.h` and `WasmValueLocation.h` moved with nothing else and are in.
- The Yarr family moves as a unit - taking `YarrInterpreter.h` alone leaves
  `YarrInterpreter.cpp` reaching for `ByteTerm::Type` members trunk renamed -
  and the unit carries real port work: ARMv7 register assignments in
  `YarrJITRegisters.h` and this port's `WEBKIT_IOS6_YARR_JIT_LOG`. It needs a
  pass that re-applies those onto trunk's files.
- `bytecode` runs into an API change that is 64-bit reasoning: trunk drops the
  `ConcurrentJSLocker` from `ValueProfile` and `ArrayProfile` updates, and this
  port holds that lock precisely because reading a JSValue pair is not atomic
  on 32-bit. Whether `decodeConcurrent()` has since made the lock unnecessary
  is the question to answer before taking that directory, not after.

Of that clean half, 57 are in and 220 files remain: B3, Air and the FTL move
as one, since nothing in them is compiled into what this port runs. What is
left needs work per family rather than per file:

- `jit` and `dfg` are held by their own families. Trunk's
  `ScratchRegisterAllocator` and `SnippetParams` speak `SnippetReg` where this
  port's inline-cache compiler passes `JSValueRegs`, and the arithmetic
  snippet headers do not match the `.cpp` files beside them. `JITCode.h` is
  not takeable at all until someone writes the 32-bit half: trunk packs a
  pointer and a type tag into one 64-bit word with `bit_cast<uint64_t>(void*)`.
- `AirOpcode.opcodes` needs trunk's `opcode_generator.rb`, as before.

The audit that found the lost adaptations is now a script:

```sh
scripts/carry-audit.py main Source/WebCore/page
```

It compares, per file, how many port markers a file carries here against the
same file on a reference branch. A file that thinned out is either an upstream
refactor or a carry that was dropped when the file was taken from trunk, and
every one of them is worth reading before a release.

## The suite was measuring a Safari without the tweak

The device suite killed Safari before every page. On a freshly launched
Safari the tweak's window-object hook is not in place for the first page it
loads, so a page that checks `window.WebAssembly` there finds nothing and
finds it on every load after that - which made whichever page happened to be
first decide whether the run reported the bridge missing. A healthy engine
reported two web-platform failures this way three runs in a row.

It is worse than the first page: Safari gets restarted during a run - this
iPad drops it under memory pressure on the heavier pages - and it does not
always come back injected at all. The warm-up page now reports whether the
bridge is there and the suite loads it before every measured page, restarting
Safari and trying again when it is not. The gap is still worth closing on the
tweak's side: the bridge should be installed for a window object that already
exists when the hook goes in, not only for the next one.

## The iPad was two deploys behind, 2026-09-14

Bringing the iPad onto the fixed engine turned up two ways a deploy can look
like it worked and not be the thing under test.

`scripts/layout-sys-frameworks.sh` took its build directory from
`ENGINE_BUILD` and defaulted to `build-254-lto`, the fork build kept for
comparison. `scripts/deploy-engine.py` does not set it, so every deploy that
did not set it by hand staged and installed the fork. The default is now the
trunk build, the one being shipped. The size of the installed
`JavaScriptCore` is the cheap check: the staged file and the file on the
device have to match.

With the right engine on it the iPad still reported `window.WebAssembly`
missing, and the warm-up page reported the bridge absent on all three
attempts before every measured page - so the suite was right and the tweak
really was not installing it. `/usr/lib/rev-safari-compat.dylib` on the iPad
was the September 10 01:34 build, 215456 bytes; the phone carries the 03:50
one, 468464 bytes, which is the first that installs the bridge from the
engine's window-object-cleared callback. The compat library is a separate
artifact from the three frameworks and `scripts/deploy-engine.py` does not
carry it, so a device can sit arbitrarily far behind on it while its engine is
current.

The iPad gate is 52 of 55 after both. The three that remain are the emoji
sequence checks: this iPad still has the 2013 `AppleColorEmoji.ttf`, and its
system partition has 133MB free against a modern 1x font of 63MB, so
installing one there is not the same cheap operation it was on the phone.

## All 5725 of JSTests/stress, twice, 2026-09-14

The whole directory was run on the phone before the map iteration fix and
again after it, same harness both times: each test gets four seconds and is
then killed, so `EXIT=137` means the test outlived its slot and `EXIT=3`
means it wants harness options this runner does not pass. What is left after
those two is the list worth reading.

Before: 30 tests. After: 13. The seventeen that went away are the ones the map
iteration fix took with it - `allow-math-ic-b3-code-duplication`, both
`ftl-get-by-id-*-interesting-live-state`, `instanceof-prototype-change-during-compilation`,
`compare-bigint-with-number` and `-with-string`, `elidable-new-object-roflcopter-then-exit`,
`redefine-property-set` and `-writable`, `string-equality-word-compare-thorough`,
`get-by-val-with-symbol`, `block-scoped-function-declarations`,
`stack-overflow-in-syntax-checker`, three `regexp-*`, and the two
`map-/set-for-each-mutation-during-iteration` that started it. `math-hypot`
passes now too.

The thirteen that remain are the device and the runner, not the engine:

- Eight ask for more memory than a 512MB phone has, and say so:
  `mmap(size=80003072) failed (error code=12)`. They are
  `array-buffer-view-watchpoint-can-be-fired-in-really-add-in-dfg`,
  `bigint-can-throw-oom`, `exhaust-gigacage-and-allocate-vm`,
  `out-of-memory-while-constructing-BytecodeGenerator`,
  `scoped-arguments-table-should-be-tolerant-for-oom`, `test-out-of-memory`,
  `typed-array-subarray-can-throw-oom-error` and
  `unlinked-code-block-destructor`.
- `ensure-crash` crashes on purpose.
- `shadow-realm-import-value` needs a module loader the shell runner does not
  give it, and the three `type-profiler-with-double-quote-in-*` need the type
  profiler turned on.

So the honest reading of the second run is that nothing in `JSTests/stress`
fails on this engine for a reason that belongs to the engine.

## Yarr came from trunk after all, 2026-09-15

The first attempt at this directory concluded it could not be taken, on the
grounds that trunk's `YarrJIT.cpp` has no feature guards left - the 41
`ENABLE(YARR_JIT_UNICODE_EXPRESSIONS)` and 12
`ENABLE(YARR_JIT_ALL_PARENS_EXPRESSIONS)` the 2023 file had are gone - and that
reinstating 53 of them in a 7800-line file upstream keeps rewriting was not
worth it.

That reading was wrong, and it is worth saying why, because the same mistake is
easy to repeat. The guards were not the whole of what the old file had. It also
carried **32-bit implementations**, and upstream deleted those together with the
branch that selected them. Two of them are on the path of every regular
expression, not in some unicode corner:

- `matchCharacterClassByBitTest` does its bit test with `lshift64` and
  `branchTest64`; the 32-bit arm does the same work with `lshift32` and
  `branchTest32`.
- `clearSubpattern` clears a capture with a single 64-bit store; the 32-bit arm
  writes the start and the end separately.

Put those back and the picture changes: what remains is a handful of guards
around code that genuinely needs registers this CPU does not have, not 53
guards around everything.

**What went back in.** `YarrJITDefaultRegisters` has its `CPU(ARM_THUMB2)` arm
again, with the seven members ARMv7 has no register for - `matchingContext`,
`freelistRegister`, `remainingMatchCount`, `regUnicodeInputAndTrail`,
`unicodeAndSubpatternIdTemp`, `firstCharacterAdditionalReadSize`,
`endOfStringAddress` - spelled `InvalidGPRReg`, which is how RISCV64 already
spells the ones it lacks. The generator has its four arms again: the
callee-save list, the `#if` in `generateEnter()` and `generateReturn()`, and the
load of the fifth argument off the stack through `POKE_ARGUMENT_OFFSET`.

Guards went back around exactly three things: the two surrogate-pair readers
and their thunk, and the backreference matcher with its canonical-equivalence
thunk. `JITFailureReason` got `DecodeSurrogatePair`, `BackReference` and
`ParenthesizedSubpattern` back, and `compile()` refuses those patterns up
front - so the JIT declines them and the interpreter takes them, which is what
the deleted guards used to arrange.

One line widens instead of returning: `storeToFrame` for a `TrustedImmPtr` was
shut off for ARMv7 in the old file and in trunk, although `storePtr` of an
immediate pointer exists on 32-bit. It is on now.

**What it bought.** All 299 regexp and yarr tests on the phone, same harness as
before: tests that threw fell from **29 to 6**, and nothing new broke. The
twenty-three are not scattered edge cases but whole features this port did not
have:

- all four `regexp-v-flag-*` - the `v` flag's class set operations;
- all four `regexp-interpreter-lookbehind-*` and all four
  `regexp-lookbehind-jit-*` - lookbehind over non-BMP characters, surrogate
  halves and backreferences;
- `regexp-unicode-property-escape-ignore-case`, `regexp-recompile`, both
  `regexp-once-through-advance-*`,
  `regexp-negative-assertion-with-bol-is-not-dropped`,
  `regexp-sticky-dot-star-wrapped-expression`,
  `regexp-backreference-greedy-non-bmp-capture-restore-pos`.

The six that still throw are the same six as before. The iPad agrees: sixteen
non-zero results, every one of them already in the old list.

**What was let go.** The port's hoisting micro-optimisations in
`YarrInterpreter.cpp` - lifting `quantityMaxCount` and `inputPosition` out of
the match loops. Upstream restructured those same loops itself, templating them
on direction and factoring out `matchGreedy`, which is the same hoisting done
structurally. The early exit in `linearSearchRanges`, the port's one semantic
change there, is kept, as are the JIT log and the latin1 table de-duplication.

**The rule this establishes.** When trunk's version of a file only deletes the
32-bit arm and adds nothing, ours is already the superset and there is nothing
to take - that is `ValueRecovery`, `DataFormat.h`, `ArithProfile`,
`MethodOfGettingAValueProfile`, `InlineAccess.h`. When trunk's version carries
real work **and** deletes the 32-bit arm, the answer is to take trunk's file and
put the arm back, not to keep ours. Yarr is the second kind, and so is most of
what is left.

## The procedure this argues for

1. Run `scripts/port-delta.py` against the current base and keep the output. It
   is the before picture, and the after picture has to be explainable.
2. Fetch the new upstream branch and diff it against the current base to see
   which of the 440 unguarded WebCore/JSC files upstream also touched. Only those
   need reading; the rest carry over.
3. Take the new tree, apply the reinstatement wholesale (WebKitLegacy, bmalloc),
   then the guarded hunks, then the read set from step 2 by hand.
4. **If the new series has dropped ARMv7** — trunk did on 2026-08-01, so any
   series cut after that has — the JIT has to be carried over as well, and the
   copy to carry is this fork's own branch, which builds and runs it today.
   `webkitglib/2.54` is the last base that supplies it for free. What comes
   across is `assembler/{ARMv7Assembler,ARMv7Registers,MacroAssemblerARMv7}.h`,
   `MacroAssemblerARMv7.cpp`, the 32-bit tiers
   (`dfg/DFGSpeculativeJIT32_64.cpp`, `jit/JITOpcodes32_64.cpp`,
   `jit/CallFrameShuffler32_64.cpp`), `offlineasm/arm.rb` and the build entries
   that name them — plus this port's own fixes on top of them, which are in the
   delta above. Expect the JSValue representation to be the hard part: see
   [armv7-jit.md](armv7-jit.md).
5. Build, then run `tests/device/run.py`. The suite is the acceptance test: it
   is numeric, it runs on the device, and it stands at 55 of 55 today.
6. Anything the suite does not cover that the update touches gets a check added
   to it first, not after.

## What the guard is for now

Of the 1309 files changed under `Source`, 375 carry the `WEBKIT_IOS6` guard and
920 do not. That number used to matter a great deal: with a graft, the guard was
the only way a future re-graft could find this port's changes without reading
every file.

Ancestry changed that. A merge finds the changes by history, so the guard's
remaining job is narrower and still worth something: it tells a person reading a
conflict which side is the port and why it is there. That is a reason to guard a
subtle hunk in code upstream is actively changing - the graphics platform layer,
the loader, JavaScriptCore's platform code - and not a reason to wrap 460 files
mechanically, which would change meaning in some of them for no benefit.

For triage during a merge:

```sh
scripts/port-delta.py --unguarded Source/WebCore/platform
```

lists the changed files in an area that carry no guard, largest diff first -
that is the read-by-hand set if a conflict lands there.

Of the 920, 81 are files that exist only in this port, 26 are build and
generator files, and 460 are source files outside the wholesale reinstatements
of WebKitLegacy and bmalloc. Their median diff is ten lines.
