# Comparing content size categories, iOS 11.0

Introduced in iOS 11.0: two functions over the content size categories iOS 7
brought — whether a category is one of the accessibility sizes, and how two of
them order.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`UIContentSizeCategoryCompareToCategory` at `0x18a3fd1e0`,
`_UIContentSizeCategoryIsAccessibilityContentSizeCategory` at `0x18a3fd070`) and
the differential test against the host's UIKit through Mac Catalyst
(`tests/backports/host/contentsize`), which compares all one hundred and
sixty-nine ordered pairs.

## The order

`UIContentSizeCategoryCompareToCategory` looks both categories up in one ordered
array — `indexOfObject:` on each — and compares the indices. The order is

    XS  S  M  L  XL  XXL  XXXL  AccessibilityM  AccessibilityL  AccessibilityXL
    AccessibilityXXL  AccessibilityXXXL

`UIContentSizeCategoryUnspecified` is not in that array: it orders **below every
category**, and equal to itself. A `nil` category orders the same way as
unspecified.

A string that is neither a category nor unspecified is refused, not ordered:
the function raises `NSInternalInconsistencyException` with

    UIContentSizeCategoryCompareToCategory cannot be used to order arbitrary strings, only UIContentSizeCategory objects (comparing %@ to %@).

## Accessibility

`UIContentSizeCategoryIsAccessibilityCategory` is true for exactly the five
`Accessibility*` categories. An unknown string answers `NO`, and so does `nil`:
this one never raises.

## The large title

`UIFontTextStyleLargeTitle`, from the same release, is the string
`UICTFontTextStyleTitle0`, which the `UIFont+TextStyles.m` backport already
answers with the system font at 34 points. Declaring the constant is the whole
of it.
