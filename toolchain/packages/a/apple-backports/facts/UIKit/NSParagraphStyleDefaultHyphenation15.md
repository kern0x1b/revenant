# NSParagraphStyle.usesDefaultHyphenation, iOS 15.0

Two rows: `NSParagraphStyle.usesDefaultHyphenation` and
`NSMutableParagraphStyle.usesDefaultHyphenation`. One object,
`packages/a/apple-backports/UIKit/NSParagraphStyle+Text15.m`, a category on the SDK's own two
classes — nothing is redeclared, which is why the file is an `@implementation` of a category
rather than of a new class.

## The status is `inert`, and the sibling row is why

`NSLayoutManager.usesDefaultHyphenation` (13.0) has been carried as **`inert`** since it landed,
in `NSLayoutManager+Text13.m`, and its effect reads: *"kept and read back, NO until set; the
first YES says so once in the log"*. That is the right status for this flag on this release and
these two rows take it for the same reason:

- **`inert` means the symbol loads and nothing applies it.** The accessor is carried, it answers
  truthfully, and the flag changes no line breaking. That is the whole truth about it.
- **`implemented` would be a claim the release cannot support.** It needs a definition the band
  exports *and* an effect that is the described behaviour. The described behaviour is "hyphenate
  as the system does by default", and the measured fact is that **the system of iOS 6 hyphenates
  nothing by default** — so there is no default hyphenation for the flag to select. An
  implementation that made lines break differently would be claiming a hyphenation engine the
  release does not have, which is the stub the workspace contract's §9 forbids.
- **`absent` would be false.** The accessors exist, are exported, and answer. "Nothing the
  release has answers the name" is not the situation.

The paragraph style is where the same flag is *set*, and the layout manager is where it would be
*read*; carrying one without the other would leave the port answering half a question, so both
halves now agree, in the same words, and both point at the same measurement.

## What the release actually carries, measured

`6.1.3`'s own Objective-C metadata, read class-scoped with the tree's own reader
(`xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7`):

| class | hyphenation selectors on 6.1.3 |
|---|---|
| `NSParagraphStyle` | `-hyphenationFactor` |
| `NSMutableParagraphStyle` | `-setHyphenationFactor:` |

So the release has the *factor* — a float multiplier, present since OS X 10.6 — and not the
*boolean*. That is precisely why the flag is kept rather than derived: there is no system
default for it to defer to, because the system exposes a factor and no default. The same reading
at 4.3 and 12.0 carries neither, which is what the rows' `source` records.

## The accessors, and what was checked about them

The storage is an associated object keyed on the style, the same mechanism
`NSLayoutManager+Text13.m` uses, and the same shape as that file's `HyphenationKey`. The helper is
`charon_menus_say_once`, which is `static inline` in `CharonMenus.h` — so **this file exports no C
symbol of its own**, which matters: a file that exported one would be a file another release's
band might also keep, and the call would be undefined symbols in the band that did not
(`AGENTS.md`, "A C function shared between backport files").

**This file compiles.** Checked with the flags `review-mechanical.sh` uses —
`xcrun clang -target armv7-apple-ios6.1.3 -isysroot <iPhoneOS16.4.sdk> -fobjc-arc -Os -g0 -Wall
-Wno-unguarded-availability-new -Wno-unguarded-availability -Werror=objc-missing-property-synthesis`
— with zero errors and zero warnings, and compiled to an object it reports **3 selectors**:
`-usesDefaultHyphenation` and `-setUsesDefaultHyphenation:` on `NSParagraphStyle`, and
`-setUsesDefaultHyphenation:` on `NSMutableParagraphStyle`, read back with the tree's own reader
(`modules/apple/objc.lua` `binary_inventory`). Both classes are carried by the 6.1.3 cache, which
is what `check_categories` requires for a category to attach. What has not happened is a link into
a band or a run on a device.

The accessors' *semantics* were checked by running that exact storage and those exact accessors on
the host, in a file with the same shape and no UIKit in it, because the port's own build cannot be
linked here without the package graph:

| check | result |
|---|---|
| a fresh style reads `usesDefaultHyphenation` | **NO** |
| after `setUsesDefaultHyphenation:YES`, the getter reads | **YES** |
| a second, untouched style reads | **NO** — the key is per-object, not per-class |
| after `setUsesDefaultHyphenation:NO`, the getter reads | **NO** (raw `0`, confirmed separately) |
| the one-time note across two styles both set to YES | printed **once** |

The fourth line is in the table because the first run of that check reported `YES` and was wrong:
the harness printed the result through a truthiness test rather than the raw `BOOL`. The storage
was right — a direct `objc_getAssociatedObject` after storing `@(NO)` returns non-nil with
`boolValue` **0** — and the harness was corrected to print the raw value, which is what the table
reports. Recording it because the corrected number is the one a reader should trust, and the
uncorrected one is the kind of thing that gets copied forward.

## What a caller sees

`[paragraphStyle usesDefaultHyphenation]` answers `NO` on a fresh style, `YES` after a set, and
`NO` again after clearing it. The first `YES` on any style prints one line saying the flag is kept
and read back and that lines will break as before. Nothing about the text changes, and the row's
`effect` says so in those words, because a caller who set this expecting hyphenation and got none
should be able to find that sentence from the row.

## Not carried, and named

The flag does not hyphenate. `NSLayoutManager+Text13.m` in the same tree carries
`-showCGGlyphs:positions:count:font:textMatrix:attributes:inContext:` and draws the glyphs itself;
hyphenating would mean inserting those soft hyphens and re-breaking the line, which is the text
engine this port does not have and does not pretend to. The layout manager's own row and this
one agree on that boundary, and neither crosses it.
