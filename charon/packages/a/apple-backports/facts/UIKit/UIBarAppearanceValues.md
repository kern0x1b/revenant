# UIBarAppearance and its descendants, iOS 13

Source: the host's own UIKit, under Mac Catalyst, asked for every answer below and held against the backport by the
`appearances` group of `tests/backports/host/uikit2/run.sh`: 1500 random sequences of 16 to 20 changes for each of
`UIBarAppearance`, `UINavigationBarAppearance`, `UIToolbarAppearance` and `UITabBarAppearance`, run on both objects
with the getters and the `description` compared after every change, and 56 scripted cases whose answers become the
expectations of `tests/backports/device/appearances.m`; and the public SDK headers of iOS 13 to 27.

## The value

A bar appearance is a plain object: nothing here draws, and the classes hold what was set and answer it back. The
newest implementation keeps for every property whether it was set at all, so that a value that was never set answers
its default and a value set to nil answers nil, and the backport keeps the same two states.

- **Idiom.** `-init` takes the idiom of the device. `-initWithIdiom:` keeps `UIUserInterfaceIdiomPad` as it is and reads
  every other value, the phone, the television, -1, as the phone. A copy and `-initWithBarAppearance:` keep it. It is
  not part of equality.
- **Background.** `backgroundEffect` is the system chrome material blur until it is set; setting nil clears it and it
  stays nil. `shadowColor` is black at 0.3 until set, and nil once set to nil. The colour, the image, the content mode
  and the shadow image are nil, 0 and nil until set. Images are kept as they are, colours and the effect are copied.
- **The three configurations.** Each starts by removing every background value, the colour, the image, the content mode
  and the shadow image included. `-configureWithDefaultBackground` stops there, so the effect and the shadow come
  back. `-configureWithOpaqueBackground` then sets the effect to nil and the colour to white and records that the
  background is visible. `-configureWithTransparentBackground` sets the effect and the shadow colour to nil and records
  that it is hidden; the two records are only in the description. None of them touches what a descendant adds: the
  titles, the button appearances, the layout.
- **The descendants differ in what they start as.** A new `UIToolbarAppearance` and a new `UITabBarAppearance` start as
  the default background. A new `UINavigationBarAppearance` starts as the transparent one, and its
  `-configureWithDefaultBackground` is the transparent one too: it is what the host answers, whatever the bar draws
  by default on a phone. An application that wants the release's own navigation bar look does not set an appearance.
- **Making one from another.** `-initWithBarAppearance:` keeps the background values and the idiom of the appearance it
  is given, and, if that is one of its own kind, everything else; from another kind it keeps the background only.
  `-copy` and `-copyWithZone:` are that, and the sub-appearances of the copy are copies of the sub-appearances.

## What a navigation bar appearance adds

- **Titles.** `titleTextAttributes` and `largeTitleTextAttributes` answer the defaults with what was set laid over
  them, key by key: a font of 17 semibold and the label colour, a font of 34 bold and the label colour. Setting nil
  brings the defaults back. Setting an empty dictionary also answers the defaults, but the description then prints them
  as if they had been set, and the backport keeps that difference. `titlePositionAdjustment` is zero, and setting zero
  stores nothing.
- **Buttons.** `buttonAppearance` starts as a plain `UIBarButtonItemAppearance`, `doneButtonAppearance` as a prominent
  one, and both answer the object the bar appearance keeps, so a change through the answer is a change to the bar
  appearance. The setters keep a copy, and a nil is refused with `NSInternalInconsistencyException`, "use
  -[UIBarButtonItemAppearance configureWithDefaultForStyle:] to reset appearance values" - in the toolbar appearance the
  same sentence names `setupDefaultAppearanceForStyle:`, which is what the host says. `prominentButtonAppearance` of
  iOS 26 is the same object as the done one, in the toolbar appearance too, and lives in a file of its own.
- **The back button.** `backButtonAppearance` is a button appearance of the back button style that falls back to
  `buttonAppearance`: the title colour and font, and the offsets and background image set on the same state of the plain
  button, are the back button's until it sets its own, and a font or colour of the plain button's style, a prominent
  one included, is passed on with them. Setting `buttonAppearance` later moves the fallback to the new object. Setting a
  back button appearance keeps a copy, whatever style it had, with the fallback.
- **The back indicator.** `-setBackIndicatorImage:transitionMaskImage:` is a pair: with only one of the two, both
  answer the default. The pair belongs to the navigation bar appearance and stays when the back button appearance is
  replaced. **Difference:** the default of both is a chevron and its mask the system draws; the backport has no such
  image to hand over and answers nil for the default, and the description says `default`.
- **Not carried.** `subtitleTextAttributes` and `largeSubtitleTextAttributes` of iOS 26 are absent: there is no subtitle
  in a navigation bar of this release, and an application that names them asks first.

## What a tab bar appearance adds

`stackedLayoutAppearance`, `inlineLayoutAppearance` and `compactInlineLayoutAppearance` start as tab item appearances of
the stacked, inline and compact inline styles, are answered as the objects the appearance keeps, are copied when set, and
refuse nil with "Use -[UITabBarItemAppearance configureWithDefaultForStyle:] to reset". `selectionIndicatorTintColor`,
`selectionIndicatorImage`, `stackedItemPositioning`, `stackedItemWidth` and `stackedItemSpacing` are nil, nil, 0, 0 and 0
until set, and setting a zero removes the value. The positioning is kept as any integer.

## Equality, the description and coding

Equality is by what is stored, and of one class: a `UIBarAppearance` is not equal to a `UINavigationBarAppearance`, two
new appearances of one kind are equal, and equal appearances have equal hashes. The effect and the shadow colour are
compared as they answer, so setting the default explicitly changes nothing. **Departures:** the host also calls an
appearance equal to a new one when an explicit zero of a background offset, or a back indicator of one image, is all that
was set; the backport compares those as set.

`-description` is the host's text, `<Class: 0x...>` and a tab-indented line per part, `Background`, `Title`,
`Plain BarButtonItems`, `Prominent BarButtonItems`, `Back Buttons`, `StackedItemAppearance` and the rest, with the
`ItemLayout` line of a tab bar appearance; the pointers in it are the parts' own. Colours print as the colours of
this release, the default shadow colour and the label colour as the plain colours they are here.

All six classes adopt `NSCopying` and `NSSecureCoding`. The archive is the backport's own: the keys are not the host's,
colours are written as their components, images as PNG data and a scale, fonts by name and size, and a text attribute
dictionary keeps its fonts, colours, numbers and strings, and drops a value of any other class, an `NSShadow` or an
`NSParagraphStyle`, where the host keeps it. A round trip gives an equal appearance. The host's own decoding of a tab
item appearance spreads an icon colour set on the normal state over the selected, disabled and focused states; the
backport keeps it where it was set.

## Departures

- The system dynamic colours, `labelColor`, the chrome shadow colour, the background colour of an opaque bar and
  the red of a badge, are the plain colours of the light appearance in this release: black at 0.847, black at 0.3, white,
  and 255, 56, 60. The differential test compares them resolved in the light style.
- The default fonts come from `+systemFontOfSize:weight:` of the port, so they are the weights the port maps to on
  iOS 6 rather than the system font of iOS 13.
- After a sub-appearance that holds an explicit zero offset is replaced through a setter of a bar appearance, the host
  sometimes keeps the zero of the object it replaced. The backport replaces it, and the random sequences keep such
  offsets out of the sub-appearances of a bar appearance, where the same offsets are compared on the button and tab item
  appearances themselves.
