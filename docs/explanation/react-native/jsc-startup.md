# Where JavaScriptCore spends the start of a React Native host

The React Native host on the iPhone 4S runs the application's bundle on JavaScriptCore. Before the Paseo screen appears,
the phone runs for about nine seconds after React starts, and the question is where that time goes. A native sampler
inside the host answers it on the real bundle: `docs/reference/react-native/jsc-sampler.md` has the method and the numbers.

## What starts when

The bundle is the Paseo application's Metro export, 24,658,515 bytes of JavaScript source with no bytecode. The host
starts React, creates the Expo app context and then hands the whole bundle to `evaluateJavaScript`. The sampler's
timeline, counted from the React start, is:

- React starts and the Expo app context is installed in about 0.7 seconds.
- `evaluateJavaScript` begins at about 0.75 seconds and returns when the application's `main` has run, at about 9.3 seconds
  without the sampler.
- After that the process keeps running the code the application calls later. The sampler did not measure when the first
  screen was complete, so this document does not give that time.

The first 1.2 seconds of sampled time are React Native's own setup on the native side and show almost nothing inside
JavaScriptCore. Almost all of the startup cost sits in the evaluation that follows.

## Parsing is the start

During the evaluation the JavaScript thread spends about three quarters of its samples inside JavaScriptCore's own code.
Of those, roughly 72 % are in the parser and bytecode generator and 5 % in other engine code. Garbage collection is
under 1 % at this point. The rest of the samples are outside JavaScriptCore's text; the sampler reports the ones inside
the kernel, where a thread is blocked, as idle and leaves them out of the shares.

Parsing happens in two passes over the same source. The first pass is the preparser (`SyntaxChecker`), which checks
the syntax of every function without building a tree. The second is the full parse (`ASTBuilder`) of the top level and
of what runs at once. The lexer alone is the largest single item: `Lexer::lexWithoutClearingLineTerminator` is about
18 % of the evaluation's samples by itself, and the member-expression and assignment parsers take another 14 % between
them. Source size drives this directly: a 24 MB bundle is lexed in full before the first line runs.

The engine parses functions lazily. Once the program runs, a function that is called for the first time is parsed and
compiled then, so parsing does not end with the evaluation. In the window after `main` it is still the largest
category, at about 36 % of the samples, with `UnlinkedFunctionExecutable::unlinkedCodeBlockFor` on the stack of most of
those.

## Execution, garbage collection and the compiler threads

After `main`, the samples move to running the application (about 16 %) and to the collector (about 14 % of the
JavaScript-thread samples, mostly `SlotVisitor::drain` and `MarkedBlock` scanning). The collector's marking runs on the
`Heap Helper Thread`, which has about 4,700 samples over the whole run, of which 8 % are inside JavaScriptCore.

The compiler is not a large cost in this window. The JIT worklist helper thread has about 4,600 samples, 7 % of them
inside the DFG compiler (`AbstractValue::clear`, `ConstantFoldingPhase::foldConstants`,
`BackwardsPropagationPhase`), and the JavaScript thread spends only about 1.5 % of its later samples in JIT or DFG
code. The compiler matters when code gets hot, and this sampling window did not tier up much of the application.

## What this means for the host

Startup on this bundle is a parsing problem first and a collection problem second. Any change that shrinks the source the
engine must lex, or that avoids the second parse of the top level, moves the start more than a change to the
interpreter or the compiler. Shipping bytecode instead of source would remove the lexing and most of the lazy parsing;
the Hermes path does that with bytecode compiled on the Mac, see [Hermes for the React Native host](../../reference/react-native/hermes.md).

The sampler measures the shape, not the exact times. It slows the host by about a quarter while it runs, it takes one
sample per thread every two milliseconds in turn, and the phase boundaries are only as exact as the moment the sampler
starts. Read the shares as the proportions of one run, not as a benchmark.
