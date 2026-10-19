# UITraitCollection layout direction, display gamut and content size category, iOS 10

Introduced in iOS 10.0: three more traits of a trait collection, each with a constructor and a getter. `layoutDirection` is left to right or right to left, `displayGamut` sRGB or P3, and
`preferredContentSizeCategory` one of the twelve content size categories; each is unspecified (-1, -1 and `UIContentSizeCategoryUnspecified`) in a collection that does not set it.

Source: the host's own UIKit under Mac Catalyst (`host/tail1/run.sh`) over `device/tail1-cases.m`, and the same cases on iOS 6 in `device/tail1.m`. A collection of no traits leaves all three
unspecified; a constructed one reads back what it was given (the twelve categories included, and unspecified for a category that is not one); a merge takes the value of the last collection that sets
one; `containsTraitsInCollection:` and `isEqual:` look at them; coding round-trips them; the description lists `DisplayGamut`, `UserInterfaceLayoutDirection` and `PreferredContentSizeCategory`,
the category by its short name (`L`), after the display scale.

## How the port does it

The three are traits of the same kind as the accessibility contrast of iOS 13: integers kept with the collection, merged, compared, described and coded by the shared trait code, with a
default for the screen: left to right (right to left when the language of the application's first localization is one), sRGB (the screens of the release do not have P3) and Large, which is the
category the release always has, as it has no Dynamic Type setting.
