# The appearance traits of a trait collection, iOS 13 and 14

Introduced in iOS 13: `accessibilityContrast`, `legibilityWeight`, `userInterfaceLevel`, and in iOS 14 `activeAppearance`, with the
collections that hold one of them, `+currentTraitCollection`, `-performAsCurrentTraitCollection:`,
`-hasDifferentColorAppearanceComparedToTraitCollection:` and `imageConfiguration`.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), asked trait by trait and through 400 random merges, and held against
the backport by the `traits13` group of `tests/backports/host/uikit2` (2434 checks); the older 335 answers of the `traits` group
still hold.

## The four traits

Each is one of three values, unspecified being -1: contrast normal 0 or high 1, legibility regular 0 or bold 1, level base 0 or
elevated 1, active appearance inactive 0 or active 1. A collection made of one has that trait and the others unspecified.
`+traitCollectionWith...:` makes it. Merging takes, trait by trait, the last collection that specifies it, as for the first traits.

- The description names `AccessibilityContrast = Normal|High` and `UserInterfaceLevel = Base|Elevated` after the style, and not the
  legibility weight or the active appearance, as the host does.
- Equality, hash and containment count all four; an unspecified trait in the wanted collection asks for nothing.
- The archive keys are `UITraitCollectionBuiltinTrait-_UITraitName` followed by `AccessibilityContrast`, `LegibilityWeight`,
  `UserInterfaceLevel` and `ActiveAppearance`, written when specified.
- `-hasDifferentColorAppearanceComparedToTraitCollection:` is YES when the style, the contrast, the level or the active appearance
  differs, the legibility weight not counting, and a nil argument counts as one with nothing specified. iOS 13 compared three of these;
  the port follows the newest.
- The collection of the screen, and so of a view and a controller, is light, normal contrast, regular legibility, base level and
  active.

The port keeps the four in an object of its own hung on the collection, so that a collection of the release's own class - on a band
that has one - answers them too; a collection the release merged does not carry them, as with the style of iOS 12.

## The current collection

`+currentTraitCollection` is the screen's collection until a block is performed as another, when it is the collection with what it
leaves unspecified filled in from the screen's. The host fills in fewer traits than the port (the size classes are not filled in) and
answers a dark style on a dark Mac, so the tests compare the appearance traits and the scale, and check the style against the light
one. Blocks nest and the previous collection comes back; `+setCurrentTraitCollection:` replaces it and nil restores the screen's.

## Image configuration

`-imageConfiguration` is the image configuration that holds the collection, the same the host answers.
