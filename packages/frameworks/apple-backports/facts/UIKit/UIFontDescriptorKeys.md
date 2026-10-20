# The keys of UIFontDescriptor, iOS 7

Source: the host's own UIKit under Mac Catalyst, asked for each string, recorded by `host/fontkeys` from
`device/fontkeys-cases.m` and read again on an iPhone 4S running 6.1.3 by `device/fontkeys.m`; CoreText of that release,
asked for the strings of its own constants.

`UIFontDescriptor` is a wrapper of a CoreText font descriptor, and its keys are CoreText's: every
`UIFontDescriptor…Attribute`, `UIFontSymbolicTrait`, `UIFontWeightTrait`, `UIFontWidthTrait`, `UIFontSlantTrait` and the two
`UIFontFeature…IdentifierKey` names the string of the CoreText constant beside it - `kCTFontFamilyNameAttribute` is
`NSFontFamilyAttribute`, and `UIFontDescriptorFamilyAttribute` is the same string. iOS 6.1.3's CoreText gives every one of these the very strings the host's does. One is not the same: `UIFontDescriptorMatrixAttribute`
is `NSFontMatrixAttribute` and `kCTFontMatrixAttribute` is `NSCTFontMatrixAttribute`, on the host and on the release alike, so a matrix
given under the key of UIKit is not the one CoreText reads; the other sixteen are.

The release exports none of the eighteen (its first is iOS 7.0), and an application that names one stops at load, whether or
not it ever builds a descriptor. The port carries them as strings.

The class is not carried - see `UIFontDescriptor.md` - so a key is what an application hands to CoreText, in a dictionary
for `CTFontDescriptorCreateWithAttributes`, and never a key of a `UIFontDescriptor`. `UIFontDescriptorTextStyleAttribute`
(`NSCTFontUIUsageAttribute`) is a key of the release's CoreText too, and nothing on the release answers it.
