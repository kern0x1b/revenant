# JavaScriptCore startup sampler: method, format and numbers

The sampler is a native thread inside the React Native host that records the program counter and the frame chain of every
thread, while the host runs the Paseo bundle on JavaScriptCore. It is a local patch of the spike host
(`rn-spike/host-app`) and is not part of the committed packages. The explanation of what the numbers mean is in
[Where JavaScriptCore spends the start](../../explanation/react-native/jsc-startup.md).

## Setup

| Item | Value |
| --- | --- |
| Revenant base | `origin/main` at `d3dbe802c` |
| Device | iPhone 4S, iPhone4,1, iOS 6.1.3, armv7, 512 MB |
| Engine | JavaScriptCore from the `webkit-engine` prebuilt (`variant system`), staged as the host's `Frameworks/JavaScriptCore.framework` by the `rn-jsc-engine` package (`--engine`) |
| Symbols | the unstripped `batteries/Frameworks/JavaScriptCore.framework` of the same prebuilt key; 46,631 `T` and `t` symbols with `nm -arch armv7 -n` |
| Bundle | the Paseo application's Metro export, 24,658,515 bytes, md5 `5321cec1d2ded5f2dfc2c79f5be5f27d` |
| Bundle id | `org.revenant.rnhost.rn-jsc-perf` |
| Sampling window | 40 seconds, started from the host's `main` before `UIApplicationMain` |

The host reads `rnhost.samp` from its application folder at start. The file holds the window in seconds; a missing or
non-positive value gives 60 seconds. The output goes to `rnhost.samp.out` in the host's run folder.

## Method

1. `thread_act_t` list from `task_threads`. The sampler skips its own thread.
2. For each other thread, in turn: `thread_suspend`, `thread_get_state` with `ARM_THREAD_STATE`, `thread_resume`.
3. The leaf is the saved `pc`; the second entry is the saved `lr`. The frame chain starts at `r7` (the frame pointer on
   armv7 iOS) and is followed with `vm_read_overwrite` until 40 frames or an unreadable address.
4. The sampler runs about every two milliseconds, one pass over all threads per tick. Each pass is one cycle; the samples
   of one cycle share one timestamp.

The chain is reliable for compiled native code that keeps a frame pointer. It is not reliable for leaf functions that do
not set one, for the JIT's own code and for the middle of a frame that is being set up. A leaf in JIT code is therefore
counted as outside JavaScriptCore's text, not as a JavaScriptCore function.

## Output format

The file is line oriented, written once at the end of each cycle.

| Line | Fields |
| --- | --- |
| `I` | `I <slide hex> <header hex> <image path>`, one per loaded image, taken from `_dyld_image_*` at start |
| `S` | `S <microseconds since start> <thread index> <thread name, may contain spaces> <pc hex> <frame pcs hex...>` |
| `E` | `E <cycles> <microseconds>`, the footer |

Thread names contain spaces (`com.facebook.react.runtime.JavaScript`, `Heap Helper Thread`), so the field after the
name is found by its hex form, not by counting fields. Unnamed threads have the name `-`.

## Symbolication

1. Find the image of the application's JavaScriptCore by the path `app/Frameworks/JavaScriptCore.framework/JavaScriptCore`.
   A system copy, such as the one in `/System/Library/PrivateFrameworks`, has its own `I` line and must not be used.
   Its slide is taken from that line, `slide` in the `I` record.
2. A sample belongs to JavaScriptCore when `pc - slide` lies in `[0, 0x2200000)`, the size of the application's
   `__TEXT`, which starts at vmaddr 0.
3. The name of a file offset is the last symbol at or below it in the sorted `nm` table (binary search). The
   stripped copy of the same engine has 7,469 symbols and cannot be used; the unstripped copy has the same addresses.
4. Names are demangled with `c++filt` in one batch.
5. Phases are cut by the sampler's own clock: phase A is before 1.2 s, phase B is from 1.2 s to 12.3 s, and phase C is after 12.3 s. The
   sampler starts about 0.3 s before the React start, so the boundaries are approximate.
6. Categories are checked on the whole stack, first match wins, in this order: GC (`JSC::Heap`, `SlotVisitor`,
   `MarkedBlock`, `Heap::`, `collectNow` and similar), parse and bytecode (`Parser`, `Lexer`, `BytecodeGenerator`,
   `UnlinkedCodeBlock`, `UnlinkedFunctionExecutable`, `SourceProvider`, `CodeBlock::`), JIT and DFG (`JIT::`, `DFG::`,
   `FTL::`, `Worklist`), execution (`LowLevelInterpreter`, `Interpreter::`, `callFunction`, `JSEvaluateScript`), and
   other JSC. A JavaScript-thread sample whose leaf is outside the engine is counted as outside JavaScriptCore text.

## Numbers

Sampled run: the 40-second window, one run, the sampler on.

| Event | Time from React start |
| --- | --- |
| React starts | 0 s |
| React started | +0.28 s |
| Expo app context installed | +0.71 s |
| `evaluateJavaScript` begins | +0.75 s |
| `Running "main"` | +12.04 s with the sampler on, +9.28 s without it |

The sampler adds about a quarter to the start. Without it, `evaluateJavaScript` takes 8.52 s. The resident size is about
142 MB five seconds after the evaluation began, about 90 MB after `main` has run and about 194 MB steady after 30 s.

### Phases, JavaScript thread

| Phase | Window | Samples | Leaf in JavaScriptCore | Parse and bytecode | Outside JavaScriptCore | Other JSC | GC | Execute | JIT/DFG |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 0 to 1.2 s | 188 | few | | | | | | |
| B | 1.2 to 12.3 s | 2,019 | 77.3 % | 71.7 % | 22.7 % | 5.0 % | 0.6 % | | |
| C | 12.3 to 40 s | 4,277 | 71.7 % | 36.0 % | 28.3 % | 3.7 % | 14.3 % | 16.2 % | 1.5 % |

The category shares of phase B and C are of all JavaScript-thread samples of that phase, so they add to 100 %.
Phase A is the React setup on the native side and is too small for shares.

### Top functions, phase B (self, share of the phase's samples)

| Function | Share |
| --- | --- |
| `JSC::Lexer::lexWithoutClearingLineTerminator` | 18.0 % |
| `JSC::Parser::parseMemberExpression<SyntaxChecker>` | 7.2 % |
| `JSC::Parser::parseAssignmentExpression<SyntaxChecker>` | 7.1 % |
| `WTF::equalInternal` | 2.7 % |
| `WTF::StringImpl::create` | 1.6 % |

Inclusive, the largest are `parseSourceElements<SyntaxChecker>` 65.3 %, `parseMemberExpression<ASTBuilder>` 57.8 %,
`Interpreter::executeProgram` 52.5 % and `parseInner` 51.4 %.

### Top functions, phase C (self)

`Lexer` 3.5 %, `SlotVisitor::drain` 1.2 %, `MarkedBlock::aboutToMark` 0.8 % and `CodeBlock::finishCreation` 0.7 %.
Inclusive, `UnlinkedFunctionExecutable::unlinkedCodeBlockFor` is about 39 %, which is the lazy parse of the functions
called for the first time.

### Threads, whole 40-second window

| Thread | Samples | Leaf in JavaScriptCore |
| --- | --- | --- |
| `com.facebook.react.runtime.JavaScript` | 6,477 | 71.5 % |
| `Heap Helper Thread` | 4,697 | 8.2 % |
| `JIT Worklist Helper Thread` | 4,597 | 7.4 % |
| `JSC Heap Collector Thread` | 1,770 | 0.2 % |
| `WebThread` | 6,544 | 0 % |
| `NSURLConnectionLoader` | 6,488 | 0 % |
| unnamed threads | 38,632 | 0.1 % |

The 69,215 samples of the run include 61,467 leaves in `libsystem_kernel`, which are blocked threads.

The helper threads' top leaves are `SlotVisitor::drain`, `MarkedBlock::isMarked` and `MarkedBlock::aboutToMark` for the
heap, and `AbstractValue::clear`, `ConstantFoldingPhase::foldConstants` and `BackwardsPropagationPhase` for the DFG
worklist.

## Limits of this run

- One run, no repeat. The shares are the proportions of this window.
- The sampler slows the host by about a quarter while it runs, so the sampled timeline is longer than the real one.
- Each cycle is a snapshot of all threads, so a thread that runs for a long time is counted once per cycle, not by its time.
- The frame chain is not reliable for leaves and for JIT code. `_malloc_zone_pressure_relief$shim` shows up as a
  leaf where the real frame is unknown and must not be read as a function of the engine.
- The phase boundaries follow the sampler's clock, which starts about 0.3 s before the React start.
- The symbols are from the unstripped copy of the same prebuilt key. A different key has different addresses.

## Reproducing the run

1. Add a sampler that follows the method above to the spike host: start it from `main` when `rnhost.samp` exists, and add
   its file to the host target's `add_files` in `xmake.lua`. Then build the host with `engine=jsc` (`isolate.lua build`,
   see [Isolated host build](../../guides/react-native/isolated-build.md)).
2. Stage and deploy the host with the bundle, then create `rnhost.samp` in its application folder with the window in
   seconds, for example `40`.
3. Launch by bundle id and wait for `Running "main"` in the host's log.
4. Fetch `rnhost.samp.out` from the run folder and run the symbolication above over the `S` lines, with the phases
   cut at the times in the table.

Remove `rnhost.samp` after the run, because the sampler adds its overhead to every later start.
