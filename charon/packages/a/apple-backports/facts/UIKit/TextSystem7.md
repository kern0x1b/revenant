# The adapters of the text system, iOS 7 to 12

Up to iOS 6 the text system of UIKit is the Mac one in UIFoundation - `NSTextContainer`, `NSLayoutManager`, `NSTextAttachment` and
`NSParagraphStyle` are there and lay out and measure text; iOS 7 renamed some of what they answer and added some. This batch names
the iOS 7 to 12 spellings over what the release has.

Source: the host's own UIKit for the defaults and the answers, recorded by `host/textsystem7` and read back on the iPad 2 by
`device/textsystem7.m`; the shared cache of iOS 6.1.3 for the selectors the release has (a walk of its classes: 255 selectors on
`NSLayoutManager` alone).

## What the port does as the system does

`NSTextContainer` takes `-initWithSize:`, `-size` and `-setSize:` for the release's container size, and answers
`-lineFragmentRectForProposedRect:atIndex:writingDirection:remainingRect:` with the release's line fragment for that sweep. The
attachment's `contents` and `fileType` are the data and the type it was made with, and `setFileWrapper:` takes the wrapper's contents.
`NSLayoutManager` takes `-CGGlyphAtIndex:`, `-enumerateLineFragmentsForGlyphRange:usingBlock:`, the enclosing rects of a glyph range,
`-propertyForGlyphAtIndex:` (null, control character and non-base character, worked out from the character, since the release keeps
only a not-shown flag), `-getGlyphsInRange:glyphs:properties:characterIndexes:bidiLevels:` and `-setGlyphs:properties:characterIndexes:font:forGlyphRange:`
(the write side, confirmed against the release's own pre-7 primitive below, not assumed from the read side's shape). The release measured a container's used
rectangle only once something had asked for its layout, and answered an empty one before; `-usedRectForTextContainer:` now lays the
container out first, as iOS 7's does. A container with exclusion paths or a line limit is no longer simple, as on the system, and lays its lines round the paths (`NSTextContainerExclusionPaths.md`). The paragraph style's `allowsDefaultTighteningForTruncation` (on, as the host has it) and
`lineBreakStrategy` are kept by the style, copied with it, held in its equality and read back.

## What it cannot do

The release's layout knows no line break mode of a container, no tracking of a text view, no tightening and no line
break strategy: those are kept and read back and the text is laid out without them (`inert`). The attachment's `bounds` is kept and the
release lays an attachment out at the size of its image. `-truncatedGlyphRangeInLineFragmentForGlyphAtIndex:` answers no range, since the
release does not say what it truncated. A paragraph style's two properties are not in its archive, and a style that the release copies
inside itself, out of its own code, loses them.

The library changes the release's own methods only where the release lacks the iOS 7 spelling of the same class, told when it loads and before
its own categories are attached: the release's `-usedRectForTextContainer:` and `-isSimpleRectangularTextContainer`, the copy and equality
of a paragraph style, and `-[NSString drawInRect:withAttributes:]`.

## The write side of glyph storage: a bridge, not a new store

`-setGlyphs:properties:characterIndexes:font:forGlyphRange:` itself is not on the release (`respondsToSelector:` NO on the iPad 2, 6.1.3,
checked against a live `NSLayoutManager` class object, not the header), and neither are its close iOS 7 relatives
(`setGlyphs:glyphIndex:layoutData:`, `setGlyph:atIndex:`). But the release's own pre-7 primitive for the same job is:
`-insertGlyphs:length:forStartingGlyphAtIndex:characterIndex:`, type encoding `v24@0:4r^I8I12I16I20` - a `const NSGlyph *` (32-bit,
the Mac text system's own glyph type, not `CGGlyph`), a count, a starting glyph index and **one** character index per call. The port
calls it once per glyph, each with that glyph's own character index from the caller's array, rather than batching the whole range under
`characterIndexes[0]` and letting subsequent characters follow sequentially: a batch call cannot express a ligature, a bidi reorder or any
other non-monotonic glyph-to-character mapping, and collapsing one into "sequential from the start" would hand a wrong map to whatever
reads it later (hit testing, selection) with nothing to show it happened. Per-glyph calls cost the same primitive, just more of it, and
cannot lose a mapping the caller actually gave.

The font argument is real but has nowhere to land yet: `NSGlyphGenerator` is a real class, but nothing in this port currently reads a
font back per glyph index for drawing or metrics (`-showCGGlyphs:positions:count:font:...`, `NSLayoutManager+Text13.m`, takes its own
font per call and never consults glyph state). A substituted font - the documented reason the parameter exists, e.g. font fallback for a
character the nominal font cannot show - is therefore not carried into anything that would render or measure differently. Mutating the
text storage's own font attribute for the affected range mid-layout was considered and rejected: it would make the substitution visible
to every attribute reader in this codebase for free, but it also risks the layout manager treating its own glyph-generation callback as
an edit to react to, and that interaction was not verified. So a divergence between the given font and the character's own
`NSFontAttributeName` is flagged once, loudly, through the same `charon_menus_say_once` this codebase already uses for a known,
inert gap (`NSLayoutManager.usesDefaultHyphenation`, `NSLayoutManager+Text13.m`) - never assumed away, never silently dropped.

Glyph properties a caller sets this way are not backed by any native setter found on the release - none was assumed, none was called
blind - so they are kept in an association on the layout manager and `-propertyForGlyphAtIndex:` consults it before falling back to the
computed answer, keeping the write side honest without inventing a call this release does not have.

## `UITextView`, measured, not assumed from iOS 7 expectations

On 6.1.3 `UITextView` carries **no TextKit surface at all**: `respondsToSelector:` is NO for `textContainer`, `layoutManager`,
`textStorage`, `textContainerInset` and `setTextContainerInset:`, checked against the live class, not the header. Its 24 ivars,
declared directly on the class (not inherited), are entirely WebKit's own: `m_webView` (`UIWebDocumentView`), `m_body`
(`DOMHTMLElement`), `m_frame` (`WebFrame`), plus editing state (`m_editable`, `m_editing`, `m_interactionAssistant`), display
attributes (`m_font`, `m_textColor`, `m_textAlignment`, `m_lineHeight`) and input plumbing (`m_inputView`,
`m_inputAccessoryView`). There is no `NSTextContainer` anywhere in the object graph for a container-shaped property to describe.
Anyone carrying `UITextView.textContainerInset` (or anything else that presumes a real text container on this class) starts from
this: the honest surface is a WebKit document view, and a container-geometry answer (`textContainer.size`, glyph-level measurement)
must be refused or absent, never a number computed against the wrong coordinate system, however plausible it looks next to
WebKit's own padding.

## `UITextView.textContainerInset`, carried onto the WebKit body it actually has

Confirmed present on the release, by `respondsToSelector:` on the live classes, not the header: `DOMHTMLElement` answers
`setAttribute:value:`, `getAttribute:` and `style`; `DOMCSSStyleDeclaration` (what `.style` returns) answers `setPadding:`,
`padding`, `setProperty:value:priority:` and `cssText`. `UIWebDocumentView` (the class `m_webView` is typed to) does **not**
answer `stringByEvaluatingJavaScriptFromString:`, so the port goes through the DOM binding directly - `m_body`'s own `.style`
- rather than JavaScript. The property: kept exactly as given (round trip, no normalization - the one thing an application can
check directly) and, on `-setTextContainerInset:`, written to `m_body.style.padding` as a CSS shorthand string in the same
top/right/bottom/left order `UIEdgeInsets` already uses.

Verified end to end in a real running application on the iPad 2, 6.1.3 (a bare daemon cannot construct a `UITextView` at all -
`initWithFrame:` traps, `SIGTRAP`, with no `UIApplicationMain` behind it): `UIEdgeInsetsMake(11, 22, 33, 44)` set through the
property reads back as exactly `top=11 left=22 bottom=33 right=44` (the round trip), and `m_body.style.padding`, read back
through the same DOM binding right after, answers `11px 44px 33px 22px` - the CSS engine's own serialization of what was set,
not merely a call that returned without crashing. No screenshot was needed or taken; the DOM's own read-back is the proof.

`textContainer`, `layoutManager` and `textStorage` remain unimplemented on `UITextView` (nothing added them): an application
asking for container geometry gets the release's own honest "does not respond", never a number computed against a WebKit box
that only looks like a text container.
