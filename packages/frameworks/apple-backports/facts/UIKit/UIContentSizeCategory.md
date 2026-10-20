# UIContentSizeCategory

Source: the strings of the host's own UIKit, printed through Mac Catalyst, and the armv7 UIKit of
iOS 9.3.5, where the same strings are in `__cstring` and the twelve symbols of iOS 7 are exported.

A category is a string, and the strings are not the names of the constants:

| constant | value |
|---|---|
| `UIContentSizeCategoryExtraSmall` | `UICTContentSizeCategoryXS` |
| `UIContentSizeCategorySmall` | `UICTContentSizeCategoryS` |
| `UIContentSizeCategoryMedium` | `UICTContentSizeCategoryM` |
| `UIContentSizeCategoryLarge` | `UICTContentSizeCategoryL` |
| `UIContentSizeCategoryExtraLarge` | `UICTContentSizeCategoryXL` |
| `UIContentSizeCategoryExtraExtraLarge` | `UICTContentSizeCategoryXXL` |
| `UIContentSizeCategoryExtraExtraExtraLarge` | `UICTContentSizeCategoryXXXL` |
| `UIContentSizeCategoryAccessibilityMedium` | `UICTContentSizeCategoryAccessibilityM` |
| `UIContentSizeCategoryAccessibilityLarge` | `UICTContentSizeCategoryAccessibilityL` |
| `UIContentSizeCategoryAccessibilityExtraLarge` | `UICTContentSizeCategoryAccessibilityXL` |
| `UIContentSizeCategoryAccessibilityExtraExtraLarge` | `UICTContentSizeCategoryAccessibilityXXL` |
| `UIContentSizeCategoryAccessibilityExtraExtraExtraLarge` | `UICTContentSizeCategoryAccessibilityXXXL` |
| `UIContentSizeCategoryUnspecified` | `_UICTContentSizeCategoryUnspecified` |

The twelve of iOS 7 are one file and the unspecified one of iOS 10 another, since a file carries the API of
one release. iOS 9.3.5 exports the twelve and neither exports nor holds the string of the unspecified one,
which is what its release says.

The release these are backported to has no dynamic type: nothing changes the category, no notification is
posted, and `UIFont`'s text styles answer the sizes of the large category, which the backport of
`UIFontTextStyle*` already gives. The constants are still what an application compares against and stores,
so they are carried; what depends on them - the comparison and the accessibility question of iOS 11 - is not
here.
