# UIFontMetrics

Introduced in iOS 11.0: scaling a font, or a measurement beside it, the way the
text style it belongs to is scaled.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`-[UIFontMetrics scaledValueForValue:compatibleWithTraitCollection:]` at
`0x18a75ece8`, `-scaledFontForFont:maximumPointSize:compatibleWithTraitCollection:`
at `0x18a75ebdc`), `UIFoundation` of the same cache
(`-[UIFont _scaledValueForValue:]` at `0x18b0f34c0`), and the differential test
against the host's UIKit (`tests/backports/host/fontmetrics`).

## How the scaling is done

`-scaledValueForValue:compatibleWithTraitCollection:` does three things:

1. takes the display scale from the trait collection, or, when there is none or
   it is zero, from `[UIScreen mainScreen].scale`;
2. asks `+[UIFont preferredFontForTextStyle:compatibleWithTraitCollection:]` for
   the font of its own text style and hands the value to that font's
   `-_scaledValueForValue:`;
3. rounds the result to the display scale with `_UIRoundToScale`, which is
   `round(value)` at a scale of one and `round(value * scale) / scale`
   otherwise — so at a scale of two, `10.3` becomes `10.5`, `10.7` becomes
   `10.5`, `0.1` becomes `0` and `-3.3` becomes `-3.5`.

`-[UIFont _scaledValueForValue:]` is where the ratio lives, and it is a ratio of
two fonts: the value is multiplied by the receiver's `_bodyLeading` and divided
by the `_bodyLeading` of the font the same style has at the default content size
category. A font that carries no `NSCTFontUIUsageAttribute` — an ordinary font
rather than one of a text style — is not scaled at all.

`-scaledFontForFont:maximumPointSize:compatibleWithTraitCollection:` refuses a
`nil` font with `NSInvalidArgumentException` and the text
`The font passed to %@ must be non-nil.`, naming the full selector, then scales
the font's point size by the same ratio and caps it at the maximum when one is
given. The answer is a new font object, and a font that is not a system one
keeps its family: Helvetica at 13 comes back as Helvetica at 13.

## What this comes to on iOS 6

iOS 6 has no dynamic type: there is one content size category and no setting
that changes it. The ratio above is therefore one — the font of a style at the
current category **is** the font of that style at the default category — and the
port says so rather than pretending to read a table it does not have. That is
this release's behaviour, not the feature being switched off: a value scaled
for a style comes back as itself, rounded to the screen scale, which is what
`scaledValueForValue:` does on any release where the category is the default
one.

The rounding, the cap, the refusal of a `nil` font and the new-object rule are
carried exactly, and the host test holds all four to the system's answers at
that same default category.

## How far this is checked

The behaviour here is deterministic, so the host differential is a real
reference rather than a set of expectations derived by hand: sixty-one checks
against the system's own UIKit, all of them agreeing. The device run is done
too, on an iPhone 4S (6.1.3, armv7) inside the safe area tweak: a whole value
left alone, a positive and a negative value rounded to the screen scale of two,
a font keeping its size, a maximum point size capping it, the default metrics
scaling like the body's, and a `nil` font refused.

One thing that run found, which no host can show: **iOS 6 interns its fonts**.
`-scaledFontForFont:` asks the font for `-fontWithSize:`, and where the size
does not change this release answers the very same object, while the host's
UIKit answers a new one. A font of another size - the capped one, for instance -
is a different object on both. Nothing in the API promises a new object, and
the port cannot manufacture one without wrapping a font it does not own, so
this is the release's own font cache showing through and the answer is equal in
family, size and descriptor either way. The device test now says so in two
checks instead of asking for an identity this release does not give.

## One divergence the port keeps on purpose

`+[UIFontMetrics metricsForTextStyle:nil]` and then a scaled value **kills the
process** on the current implementation: the exception comes out of a dispatch
barrier inside UIKit's own cache, where it cannot be caught, so the program
ends. The port simply treats the missing style as a style it does not know and
scales by one.

This is left as it is on purpose. The rule of this package is the behaviour of
the newest implementation, and an abort is not behaviour - there is nothing for
an application to observe, catch or rely on, and a port that reproduced it
would only take a program down in a place where it need not go down. It is
written here so that nobody later reads the difference as a bug and fixes the
port into crashing.

