# The bar tint colour, the back indicator and the search bar style, iOS 7

Source: the host's own UIKit, under Mac Catalyst, asked for each property and held against the backport by
`tests/backports/host/uikit2/run.sh`, which sets the same values on both and compares what they answer;
and iOS 6.0 and 6.1.3 on an iPhone 4S, an iPad 2 and in the emulator, through `tests/backports/device/uikit2.m`.

## The bar tint colour

`barTintColor` of a `UINavigationBar`, a `UIToolbar`, a `UITabBar` and a `UISearchBar` is nil until it is
set, answers the very colour it was given, and is a property of its own: setting it leaves the bar's
`tintColor` as it was, setting `tintColor` leaves it as it was, and clearing it leaves a `tintColor` an
application set. In iOS 7 the bar tint colour is the colour of the bar and the tint colour the colour of
what is on it.

iOS 6 has one colour, and it is `tintColor`: a bar of that release is tinted by it. So the backport keeps the bar tint colour and hands it on to the bar's `tintColor`, on
all four bars, and clearing it clears that too. That is the one place this differs from the newest system
and it cannot be made to agree: `tintColor` is the release's own, and the backport never replaces a method
the release has. An application that sets both, meaning the bar and its items, gets on iOS 6 the one it
set last for the bar.

## The back indicator

`backIndicatorImage` and `backIndicatorTransitionMaskImage` of a `UINavigationBar` are a pair. Each is
nil until set and each answers the image it was given, but only while both are set: with an image and no
mask, or a mask and no image, both answer nil. Neither is lost for that - a mask set first answers again
the moment an image is given, one cleared and set again brings the other back, and replacing one keeps the
other. The device test holds iOS 6 to that, and the host test to the system's over every order of six
changes to the two, set, cleared and replaced.

The two images are what iOS 7 draws the back button's arrow and its transition with. iOS 6 draws its own
back button and has no place for them, so the backport keeps them and answers them and draws nothing with
them: they are `inert`.

## The search bar style

`searchBarStyle` is `UISearchBarStyleDefault` (0) until set and keeps only the low three bits of what it is
given: 8 reads as 0, 9 as 1, 15 and 255 as 7, -1 as 7 and -2 as 6. Alongside the value, the backport keeps
the look iOS 7 gives a minimal search bar. It has no such look to select, so a bar whose style is
`UISearchBarStyleMinimal` and that has no background image of an application gets a clear one of its own,
and loses it again when the style is any other; a background image an application set is left alone
both ways.
