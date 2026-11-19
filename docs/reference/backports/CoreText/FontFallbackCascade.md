# CoreText: the font fallback cascade on iOS 6

On iOS 6.1.3 a run of text with a code point that none of its font's cascade fonts covers makes CoreText walk the whole
font database. The backports give every font a cascade that ends in `LastResort`, so the walk never starts.

## The fault

`CTTypesetter` asks the font for a fallback with `TFontCascade::CreateFallback`. When the font's cascade does not cover
the code point, that goes to `CreateSystemWideFallback` and `CopyDescriptorsForRequestFromArray`, which enumerates every
font file of the device and maps each one. The walk finds nothing for a code point that no installed font has, and the
result is the `LastResort` glyph (glyph 8). The answer is not cached per code point, so the next layout of the same code
point walks again.

Measured:

| where | files mapped | address space mapped below `0x30000000` | time |
| --- | --- | --- | --- |
| iPhone 4S, iOS 6.1.3 | 90 files of `/System/Library/Fonts/Cache` (213412 K) | +229 MiB | 680 to 760 ms |
| emulator, iOS 6.1.3 | the same files | +171 MiB | about 440 ms |

On the phone the first layout that reaches an uncovered code point costs that address space for good (the files stay
mapped), and Telegram's emoji panel then fails with `ENOMEM`.

## What the backports do

A font that has a `kCTFontCascadeListAttribute` is laid out through that list and the walk does not start. So the
backports attach one:

- the list is `CTFontCopyDefaultCascadeListForLanguages` for the font (24 descriptors on 6.1.3) followed by the
  `LastResort` descriptor;
- a list the caller gave with `kCTFontCascadeListAttribute` is kept, and `LastResort` is appended only when it is not
  the last entry (never replaced: `[LastResort]` alone would replace the default cascade, which was measured);
- the default list is built once per PostScript name and cached (62 to 64 ms on the 4S for the first build), and the
  font made from it is cached per source font;
- every release from iOS 7 on is untouched: each entry point checks `NSFoundationVersionNumber` and returns the system's
  font.

Measured with the list attached: 2.3 MiB mapped and about 10 ms instead of 171 MiB, the same run fonts and glyph ids
for Latin, CJK, Arabic, Thai, Indic, emoji and mixed text, and the same name, size, matrix and metrics as the system's
font.

## Where it is attached

`frameworks/Backports/src/CoreText/CTFontCascade6.m` (in `libCoreTextBackports.dylib`) defines, as plain strong
definitions, the creators that exist on iOS 6.1.3: `CTFontCreateWithName`, `CTFontCreateWithFontDescriptor`,
`CTFontCreateCopyWithAttributes`, `CTFontCreateCopyWithSymbolicTraits`, `CTFontCreateCopyWithFamily`,
`CTFontCreateUIFontForLanguage` and `CTFontCreateWithGraphicsFont`. Each calls the system's function and returns its font
with the cascade attached.

It has to be a plain definition and not `BACKPORT_IMPL`: `BACKPORT_IMPL` defines only the fallback that the generated
forwarder calls when the device lacks the symbol, so on a device that has the function the system's runs and the
definition never does (`frameworks/Backports/README.md`, "Limits").

`frameworks/Backports/src/UIKit/UIFont+Cascade6.m` (in `libUIKitBackports.dylib`) covers the UIKit creators. A `UIFont`
on iOS 6 is not a `CTFont`: `+systemFontOfSize:` answers a `UICFFont` that holds a `CTFont` (`-ctFontRef`) at offset
`0x30` of the object, so a function that takes a `CTFontRef` cannot be given a `UIFont`. At `+load` it replaces
`+fontWithName:size:`, `+systemFontOfSize:`, `+boldSystemFontOfSize:`, `+italicSystemFontOfSize:` and `-fontWithSize:`
(the weight creator and the others of the backports are built on them): each calls the original and swaps the held
`CTFont` for the cascaded one, only when the slot still holds the font that `-ctFontRef` returned. A `UIFont` that is
laid out through `CTTypesetterCreateWithAttributedString` therefore does not walk either.

Both files share `frameworks/Backports/src/revenant_font_cascade.h`.

## What is not done

- A `UIFont` made by a UIKit creator that this page does not list keeps the system's cascade.
- A new emoji (Unicode 7 and later) that no font in the cascade covers still draws `LastResort`: stock 6.1.3
  `AppleColorEmoji` lacks them, and CoreText finds the installed emoji font only through a built-in range table. An
  explicit `AppleColorEmoji` run font would draw the installed font's glyph without a walk (measured on the 4S, 66.5 MiB);
  that is not in the backports.
- `CTFontCreateWithNameAndOptions` and the other creators of iOS 7 and later do not exist on 6.1.3 and are not defined.

## The runtime case

`frameworks/Backports/tests/runtime/cases/coretext_fallback_cascade.m` runs each creator in its own process (the walk is
measured as address space mapped below `0x30000000`, which a second walk in the same process would hide):

- for each creator (`UIFont` system, named, bold, resized and weight; `CTFontCreateWithName`,
  `...WithFontDescriptor`, `...CopyWithAttributes`; a caller's own list) a code point no font covers maps under 8 MiB
  more and the run font is `LastResort`;
- the control, the system's own creator reached by `dlsym`, maps over 100 MiB;
- the app's `CTFontCreateWithName` and `CTFontCreateCopyWithAttributes` bind to `libCoreTextBackports.dylib` (`dladdr`),
  so the case is built and linked the way an app is and proves that two-level namespace reaches the definition;
- a list the caller gave is kept and `LastResort` appended once (a second pass leaves it);
- Latin, CJK, Arabic, Thai, Indic and emoji text gets the same run fonts and glyph ids as the system's font.

`coretext_fallback_probe.m` is the measurement that found the walk.
