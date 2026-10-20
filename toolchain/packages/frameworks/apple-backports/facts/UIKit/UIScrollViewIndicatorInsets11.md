# The insets of the vertical and the horizontal scroll indicator, iOS 11

iOS 11 gave a scroll view two more sets of insets beside `scrollIndicatorInsets`: `verticalScrollIndicatorInsets` for the indicator that runs down the right edge and
`horizontalScrollIndicatorInsets` for the one along the bottom. An application that keeps a tab bar or a keyboard clear of the vertical indicator sets the first with a bottom of its height.

Source: UIKit of the arm64 shared cache of iOS 11.0 and 12.0 - `-verticalScrollIndicatorInsets` and its setter (0x1ace9b5f0 and 0x1ace9b5a8 of 12.0), the same of the horizontal set,
`-setScrollIndicatorInsets:` at `0x1ace9b51c` and `-_effectiveVerticalScrollIndicatorInsets` at `0x1aceb2640` - and the host's UIKit under Mac Catalyst, recorded by
`tests/backports/host/traits11/run.sh` (the getters of both sets after each step, on a scroll view and a table view) and held to the same records on an iPad 2 on iOS 6.1.3 by `tests/backports/device/uikit12.m`, which passed all 100 of its checks there, the resting place of the indicator among them.

## What the release does

The scroll view keeps three sets: the one an application gave to `scrollIndicatorInsets`, and one each for the vertical and the horizontal indicator, which are unset - a number no inset can be - until they are given.
The getter of an unset set answers the `scrollIndicatorInsets` one; a set one answers what it was given. Giving `scrollIndicatorInsets` a value unsets both, and `scrollIndicatorInsets` itself keeps answering the value given to it whatever
the other two hold. An indicator is placed by its own set, added to the insets the scroll view derives from its content inset and safe area.

## What the port does

iOS 6 has one set, in which the vertical indicator takes its top, bottom and right and the horizontal one its left, right and bottom, so the port keeps the three sets as the release does, with the same answers, and
hands the release's `scrollIndicatorInsets` what the two sets make: the top, bottom and right of the vertical set where it is set, the left of the horizontal set where it is set, and the rest from what the application gave to
`scrollIndicatorInsets`. `scrollIndicatorInsets` answers that value of the application and not the merge, and setting it again unsets both other sets, as in the release. A table view or a collection
view is a scroll view here and does the same.

The two indicators still share a bottom and a right: a bottom given to the vertical set also lifts the horizontal indicator by it, and the right of the vertical set is also the end of the horizontal one. An application that gives
the two sets different bottoms sees the horizontal indicator where the vertical set puts it. No indicator is shown without a scroll, which is why the device test reads the answers and the merge the release is handed rather than a picture.
