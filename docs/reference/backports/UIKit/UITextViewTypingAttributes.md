# `-[UITextView typingAttributes]` on iOS 6.1.3

`typingAttributes` exists on iOS 6. For a text view that has no selection yet it faults before it can return attributes.
The backport replaces the getter and `setTypingAttributes:` on `UITextView`, only on releases before iOS 7, and leaves
the system implementation in charge wherever a selection exists.

## The fault

Measured in the runtime harness (emulated iPhone 4S, 6.1.3, case `uitextview_typing_attributes`) with the backport's
source file removed from the build: the case dies on the first `typingAttributes` of a fresh view with signal 11 in
`WebCore::Frame::styleAtSelectionStart() const` at `+0x9c` (the emulator's symbolizer names it), `fault=0x4`, `r1=0x0`.
The caller frame is `-[UIWebDocumentView typingAttributes]` at `+0x2b`. To reproduce, remove
`frameworks/Backports/src/UIKit/UITextView+TypingAttributes6.m` and run `./xmakew test -P . backports_runtime/uitextview_typing_attributes`
on a device-tests configuration.

The same fault came from the 4S in Telegram 13.2: reports `crash-RP-*` and `crash-RW-*` in
`telegram-build/.agent-work/scratch-login/memprobe/` (outside this repository) give `EXC_BAD_ACCESS`,
`KERN_INVALID_ADDRESS at 0x4`, pc `0x38955858` in WebCore (load address `0x38540000`, so offset `0x415858`, the same low
bits as the emulator's pc `0x374c8858`) and a frame in UIKit at `0x34653d0e` (load address `0x343f5000`, offset `0x25ed0e`).

The two frames above name `-[UIWebDocumentView typingAttributes]` calling `WebCore::Frame::styleAtSelectionStart()`,
which dereferences a null selection result. That `-[UITextView typingAttributes]` forwards to the web document view is
reasoned from the case calling only the `UITextView` method; no disassembly of that link is claimed.

## The condition

Measured with a throwaway probe case on 6.1.3 (run 2026-11-19; the probe is not committed, its two lasting findings are
asserted by the case, marked below), the `selectedRange` of a text view:

| Step | `selectedRange` |
| --- | --- |
| fresh view | `{NSNotFound, 0}` (asserted by the case) |
| `text = @"hello"` | `{5, 0}` |
| `setSelectedRange:{2,0}` | `{2, 0}` |
| `text = @""` after a selection | `{0, 0}` (asserted) |
| `attributedText` set | `{0, 0}` |
| `resignFirstResponder` | unchanged (asserted) |
| `becomeFirstResponder` with no window | answers `NO`, unchanged |
| `editable = NO` | unchanged |
| added to a window, removed from it | unchanged |
| `setSelectedRange:{NSNotFound,0}` | ignored, unchanged |
| caret at `{4,0}`, then the text cut to two characters | `{2, 0}`, kept inside the text |

So `{NSNotFound, 0}` is the whole of the no-selection state, and a view that leaves it never comes back. The backport
treats a location of `NSNotFound` as no selection and every other range as a selection; it does not look at the text
length, because the system keeps the range inside the text.

## What a later UIKit answers

The Mac Catalyst program `frameworks/Backports/tests/uitextview_typing/oracle.m` (`arm64-apple-ios17.0-macabi`, macOS 27
UIKitCore, plain `main`, Info.plist embedded with `-sectcreate`) prints one row per state, and
`frameworks/Backports/tests/uitextview_typing_oracle_test.lua` builds it and asserts every row below on the host.

| State | `typingAttributes` |
| --- | --- |
| empty default view | one key, `NSColor`; the default `font` is nil there |
| font 19, red text colour, centred | `NSFont`, `NSColor`, `NSParagraphStyle` with alignment centre |
| `setTypingAttributes:` font 23 and blue | the same two come back |
| set, then the caret moved to another place | cleared: back to the view's own answer |
| set, then the same range assigned | kept |
| set, then a range selected | cleared |
| set, then `textAlignment` centre | kept, and the paragraph style is added |
| `font` and `textColor` assigned nil | both read nil; the answer has no keys |
| font 15, `textAlignment` assigned left | three keys, paragraph style present with alignment left |
| font 15, `textAlignment` never assigned | two keys, no paragraph style |

## The answer

Where there is no selection the replacement answers from the view's own properties, as the oracle does for a view with
a font: `NSFontAttributeName` from `font`, `NSForegroundColorAttributeName` from `textColor`, and
`NSParagraphStyleAttributeName` with the view's `textAlignment` when it is not left. On 6.1.3 `font` and `textColor`
are never nil, even after nil is assigned (measured by the probe), so the two keys are always there; the nil tests in
the code matter only to a subclass that overrides the properties.

`setTypingAttributes:` with no selection is stored on the view as a copy and returned by the getter. With a selection both
calls go to the system implementation, and the system clears what was set when the selection moves: measured on 6.1.3
by the probe and asserted by the case (the later UIKit rows above are the same).

Stored attributes cannot go stale. They exist only in the no-selection state; the first accessor call after a selection
appears drops them and answers through the system; and the state cannot be re-entered (table above). So the lazy drop
is exact, not an approximation of an event.

One known divergence from the oracle: later UIKit adds a paragraph style once `textAlignment` has been assigned, left
included. The backport cannot tell an assigned left from the default by reading the property, so such a view gets no
paragraph style; the case pins this with its own check. Intercepting `setTextAlignment:` to record the assignment would
make it match, at the price of a third replaced method; the paragraph style changes nothing that is drawn, so it was
not done (reasoned, not measured).

The accessors, like every `UITextView` call, are for the main thread; the stored attributes use a nonatomic association.

## Releases

The replacement is installed only when `NSFoundationVersionNumber` is below `NSFoundationVersionNumber_iOS_7_0`, the
guard `UILabel+Background7.m` and `UISwitch+Appearance7.m` use. The fault is measured on 6.1.3 only. The line at iOS 7 is
reasoned: iOS 7 rebuilt `UITextView` on TextKit (`UITextView+TextKit7.m` exists because 6 lacks `isSelectable`), so the web document view path that faults is not there, and the later UIKit rows above come from a
text view without WebCore. Releases before 6.1.3 were not run.

## Subclasses

`UITextView` implements both accessors itself, so the backport replaces those IMPs with `method_setImplementation` on
`UITextView`. A subclass that overrides `typingAttributes` and calls `super` reaches the replacement, and one that does
not override inherits it; the case has a subclass that calls `super`.

## How it is tested

`frameworks/Backports/tests/runtime/cases/uitextview_typing_attributes.m` runs in the daemon harness. A text view needs a
host there: the case calls `[UIApplication sharedApplication]`, loads GraphicsServices and calls `GSInitialize`, then
calls `WebKitInitialize` (present on 6.1.3). Without the backport the case dies with the fault above; with it every
check passes and the negative pass fails every check.

| File | Contents |
| --- | --- |
| `frameworks/Backports/src/UIKit/UITextView+TypingAttributes6.m` | the two replacement accessors and their installation |
| `frameworks/Backports/tests/runtime/cases/uitextview_typing_attributes.m` | the case |
| `frameworks/Backports/tests/uitextview_typing/oracle.m` | the Catalyst program for the later UIKit |
| `frameworks/Backports/tests/uitextview_typing_oracle_test.lua` | builds the program and asserts its rows |
