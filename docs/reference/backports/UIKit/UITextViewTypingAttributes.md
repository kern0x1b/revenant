# `-[UITextView typingAttributes]` on iOS 6.1.3

`typingAttributes` exists on iOS 6. For a text view that has no WebCore selection it faults before it can return
attributes. The backport replaces the getter and `setTypingAttributes:` on `UITextView` and leaves the system
implementation in charge wherever a selection exists.

## The fault

Raw reports from the 4S (Telegram 13.2, `telegram-build/.agent-work/scratch-login/memprobe/crash-RP-*`, `crash-RW-*`):

| Fact | Value |
| --- | --- |
| Exception | `EXC_BAD_ACCESS (SIGSEGV)`, `KERN_INVALID_ADDRESS at 0x4`, main thread |
| UIKit load address | `0x343f5000`, UUID `ad8b3ad23f413187a178179db39cfa6b` |
| WebCore load address | `0x38540000`, UUID `06c849df1ad435aeb8b6130d85cee5df` |
| pc | `0x38955858` = WebCore + `0x415858` |
| frame 1 | `0x34653d0e` = UIKit + `0x25ed0e` |
| registers | `r1 = 0`, `lr = 0` |

The instruction at WebCore + `0x415858` is `ldr r1, [r1, #0x4]` with `r1 == 0`. It sits in
`WebCore::Frame::styleAtSelectionStart() const`, `+0x9c` into the function (the emulator's symbolizer names it; the
function starts at WebCore + `0x4157bc`). The value that is dereferenced is the result of the selection lookup inside
the function, null when the frame has no selection.

The same fault was reproduced in the runtime harness on the emulated 6.1.3 without the backport (case
`uitextview_typing_attributes`): pc in `WebCore::Frame::styleAtSelectionStart() const` +0x9c, `fault=0x4`, `r1=0x0`, the caller frame
`-[UIWebDocumentView typingAttributes]` +0x2b (UIKit), immediately after the case printed a fresh view's
`selectedRange {2147483647, 0}`.

The chain, by disassembly of `.cache/dyld/6.1.3/dyld_shared_cache_armv7`:

```
-[UITextView typingAttributes]            UIKit+0x228f18, forwards to the web document view
  -> -[UIWebDocumentView typingAttributes]  UIKit+0x25ed0e
    -> WebCore::Frame::styleAtSelectionStart()
      -> NULL dereference at [r1+4]
```

## The condition

`-[UITextView selectedRange]` (UIKit IMP `0x33110624`) sends `_selectedNSRange` to the same web document view, a different
selector, and does not enter `styleAtSelectionStart`. Measured in the runtime harness on iOS 6.1.3 (case
`uitextview_typing_attributes`, `typing fact:` lines):

| State | `selectedRange` |
| --- | --- |
| fresh `UITextView`, no text | `{2147483647, 0}` (`NSNotFound` location) |
| text set, `setSelectedRange:{2,0}` | `{2, 0}` |

So the backport treats a location of `NSNotFound`, or a range ending past the end of the text, as "no selection" and
leaves every other state to the system implementation.

## What a later UIKit answers

Measured with a Mac Catalyst program (`arm64-apple-ios-macabi`, macOS 27, UIKitCore; plain `main`, no
`UIApplicationMain`, Info.plist embedded with `-sectcreate`) on `UITextView` with no application window:

| State | `typingAttributes` |
| --- | --- |
| defaults, empty | `{NSColor}` only; the default `font` is nil there, `textColor` is the dynamic label colour |
| `font` 19, red `textColor`, centred | `NSFont`, `NSColor` and `NSParagraphStyle` with alignment centre |
| only `font` set | `{NSFont, NSColor}`, no paragraph style |
| `font` set and `textAlignment` set to each of left, centre, right, justified, natural | three keys; the paragraph style is present and carries that alignment, left included |
| `textColor = nil` and no font | `{}` |
| `setTypingAttributes:` with font 23 and blue | the same font and colour come back; two keys, no paragraph style |
| `selectedRange` set to the range it already has | the set attributes stay |
| text `hello` red, caret at 2 | red `NSColor` |

The AppKit `NSTextView` answer is not the oracle: UIKit's own later implementation is.

## The answer

Where there is no selection the replacement answers the view's own properties, the same as later UIKit for a view with
a font:

- `NSFontAttributeName` from `font`, when non-nil;
- `NSForegroundColorAttributeName` from `textColor`, when non-nil;
- `NSParagraphStyleAttributeName` with the view's `textAlignment`, when it is not left.

A deliberate divergence: later UIKit adds the paragraph style once `textAlignment` has been assigned, even to left. iOS 6
cannot tell an assigned left from the default, so a left-aligned view gets no paragraph style (which is what an untouched
later view answers).

`setTypingAttributes:` with no selection is stored on the view (associated object, a copy) and returned by the getter. It
is dropped as soon as the getter or setter finds a selection, which is what "cleared when the selection changes" means.
With a selection both calls go to the system implementation.

## Subclasses

`UITextView` implements both accessors itself, so the backport replaces those IMPs with `method_setImplementation` on
`UITextView`. A subclass that overrides `typingAttributes` and calls `super` reaches the replacement; a subclass that does
not override gets it by inheritance. The runtime case has a subclass that calls `super`.

## How it is tested

`frameworks/Backports/tests/runtime/cases/uitextview_typing_attributes.m` runs in the daemon harness. A text view needs a
host: the case calls `[UIApplication sharedApplication]`, loads GraphicsServices and calls `GSInitialize`, then calls
`WebKitInitialize` (present on 6.1.3). Without the backport the first `typingAttributes` on a fresh view dies with the
WebCore fault above; with it the nine checks pass and the negative pass fails all of them.

| File | Contents |
| --- | --- |
| `frameworks/Backports/src/UIKit/UITextView+TypingAttributes6.m` | the two replacement accessors and their installation |
| `frameworks/Backports/tests/runtime/cases/uitextview_typing_attributes.m` | the case |
