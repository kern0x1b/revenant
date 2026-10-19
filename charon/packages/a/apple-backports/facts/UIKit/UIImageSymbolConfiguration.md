# UIImageConfiguration and UIImageSymbolConfiguration, iOS 13.0

Introduced in iOS 13.0: how an image is to be drawn - the traits it is drawn under, and for a symbol image its point size or text style, weight and
scale. Both are immutable value objects. iOS 6 draws no symbol, so nothing reads them but the application and `UIImageView` (`UIImageSymbols.md`).

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the `symbols` group), which
compares the descriptions, identities, equality, hashes, archives and answers to arguments of both classes over the factories, the four `without...`
methods and every pair of a set of configurations.

## As UIKit does

- `UIImageSymbolConfiguration` descends from `UIImageConfiguration`, which descends from `NSObject`; both adopt `NSCopying` and `NSSecureCoding`.
  `-init` and `+new` are unavailable in the header and work all the same: a configuration with nothing specified.
- A configuration holds a point size or a text style (never both from the factories), a weight, a scale and, in the base class, a trait collection. Zero
  weight and zero scale are "unspecified". `+unspecifiedConfiguration` is one shared object.
- `+configurationWithPointSize:...` makes any size that is not above zero, and NaN, into 17. `configurationWithFont:` is not so: it keeps the size of the
  font as it is, zero for no font, and takes the weight from the font's weight trait through `UIImageSymbolWeightForFontWeight`, so that a font with no
  trait, and no font, is Regular. The trait is the one CoreText gives (`kCTFontWeightTrait`); `Helvetica-Bold` and the other fonts whose trait is the double
  0.4 come out Semibold, since Bold starts at the float 0.4, and only a font whose trait is that float, as the system font's is, comes out Bold.
- `+configurationWithTextStyle:` keeps the string it is given as it is, not a copy, and nil, empty and unknown strings too; nil is a configuration with
  no text style. A weight or scale that is none of the enumeration's values is kept: a weight has no name in the description, a scale is "Unknown".
- `-configurationByApplyingConfiguration:` answers the same object for nil, for an unspecified one, and - a symbol configuration only - for an equal one.
  Otherwise it is a copy, and the applied configuration's traits are merged over its own with `+traitCollectionWithTraitsFromCollections:` when the
  receiver is of the applied one's class or below it; a plain configuration applied over another kind leaves the traits alone. A text style or a point
  size of the applied one replaces the other of the two and the receiver's weight stays unless it has one; the scale, weight and traits are replaced
  one by one where the applied one has them.
- `-configurationWithoutScale`, `WithoutWeight` and `WithoutPointSizeAndWeight` answer the same object when there is nothing to remove.
  `-configurationWithoutTextStyle` makes the size of the style in its place - 34 for large title, 28, 22, 20 for the titles, 17 for headline and body, 16, 15,
  13, 12 and 11 - or a size of zero for a style that is not one, and none at all when the traits have no content size category, since the size is
  then not known.
- `-configurationWithTraitCollection:` replaces the traits, and answers the same object when they are equal; a value that is not a trait collection raises
  `NSInvalidArgumentException`.
- `-isEqualToConfiguration:` compares every value, exactly, and the traits; nil is equal to a configuration that has nothing specified and to no other.
  The base class has the method too and is equal to nothing but a configuration of its own class. `-hash` is the point size times a hundred, the weight, the
  scale, the hash of the text style and of the traits, exclusive-or'd; `-isEqual:` is the same as `-isEqualToConfiguration:`.
- `-copy` is always another object. `-description` is a list of `pointSize=17`, `textStyle=...`, `weight=Ultra Light|Thin|Light|Regular|Medium|Semibold|Bold|Heavy|Black`,
  `scale=Default|Small|Medium|Large` and `traits=(...)`, in that order, or `unspecified`; the traits are the words the trait collection prints.
- Archiving writes `UIPointSize` (a double, when it is not zero), `UISymbolWeight` and `UISymbolScale` (when they are not zero), `UITextStyle` and, in the base
  class, `UITraitCollection`. A point size that is present is specified, even zero, and one below zero is read as zero.

## Where the port differs

- A font that comes from `+preferredFontForTextStyle:` gives a size and a weight and never a text style: the fonts of iOS 6 carry none, and the host
  keeps the style of such a font. So `configurationWithFont:` of the body font is `pointSize=17, weight=Regular`, where the host's is
  `textStyle=UICTFontTextStyleBody, weight=Regular`, and a font scaled by a `UIFontMetrics` is a size as well.
- The weight of a font on iOS 6 is read from a font made by name, `CTFontCreateWithName`, where the host's UIFont is the CoreText font itself.
- The port's trait collections have no content size category, so `-configurationWithoutTextStyle` of a configuration with traits always leaves the size
  unspecified there; the rule is the host's, and the comparison against the host holds it with and without a category.
- Later releases' members - colours, the variable value and rendering modes, `+configurationWithTraitCollection:`, `locale` - are not there, and
  `respondsToSelector:` says so.
