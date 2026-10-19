# Trait collections and the trait environment, iOS 8

Source: the host's own UIKit, under Mac Catalyst, asked for each answer below and through
`tests/backports/host/uikit2/run.sh`, which holds the backport and the system to the same 335 answers; UIKit
of iOS 8.0 armv7, read from its instructions for the traits of a screen; and iOS 6.0 on an iPhone 4S in the
emulator, asked for the environment of controllers and views.

## The collection

A `UITraitCollection` is an immutable value of four traits: `userInterfaceIdiom`, `displayScale`,
`horizontalSizeClass` and `verticalSizeClass`. One made from none answers idiom `-1`
(`UIUserInterfaceIdiomUnspecified`), scale 0 and both size classes 0, and one made with a single trait
answers that trait and the unspecified value of the other three. A trait is kept as given whatever it is:
an idiom of 9 and a size class of 5 read back as 9 and 5, a scale of 2.5 as 2.5.

`+traitCollectionWithTraitsFromCollections:` takes, trait by trait, the last collection that specifies it,
and an unspecified trait - idiom -1, scale 0, size class 0 - never erases one an earlier collection gave: the
scales 1, 2 and 0 merge to 2. A nil array and an empty one answer the empty collection. Anything in the
array that is not a `UITraitCollection` - `NSNull`, a string, a number, any object - raises
`NSInvalidArgumentException` naming the argument: "Arguments to traitCollectionWithTraitsFromCollections:
must all be of type UITraitCollection". The test asks the system for that once, at its very end: the
newest system leaves an `os_unfair_lock` held when it raises, and the next call of the method on the same
thread aborts the process.

`-containsTraitsInCollection:` is YES when every trait the other collection specifies is the same here, so a
full collection contains a scale and a scale does not contain the full one; it answers YES for nil.
`-isEqual:` and `-hash` compare the four traits, `-copy` answers the object itself, and `-description` names
them in that order - `UserInterfaceIdiom = Phone, DisplayScale = 2, HorizontalSizeClass = Compact,
VerticalSizeClass = Regular`, with a trait that is unspecified left out. The class supports secure coding
and archives its traits under the four keys `UITraitCollectionBuiltinTrait-_UITraitName` followed by
`UserInterfaceIdiom`, `DisplayScale`, `HorizontalSizeClass` and `VerticalSizeClass`; the style of iOS 12 is a
fifth trait, [written down of its own](UITraitCollectionUserInterfaceStyle.md).

## What a screen answers

`-[UIScreen _defaultTraitCollectionForInterfaceOrientation:]` in UIKit of iOS 8.0 (0x251b465c) merges the
screen's idiom and its scale with a horizontal and a vertical size class it reads from the size of the
screen in that orientation - and, in the same collection, the private interaction model and touch level
that no public trait names and the backport does not build. Given no orientation it adds no size class at
all. The two classes come from two small functions, both asking the **device's** idiom, not the screen's:

| | the device is a phone | the device is a pad | any other idiom |
|---|---|---|---|
| horizontal (0x254b9b4c) | regular above 667 points, else compact | regular above 667 points, else compact | unspecified |
| vertical (0x254b9bc0) | regular from 480 points, else compact | regular whatever the height | unspecified |

The 667 and the 480 are float literals of those functions (0x254b9bbc and 0x254b9c38). They make an iPhone 4S
in portrait (320 by 480) compact by regular, in landscape (480 by 320) compact by compact, and any iPad
regular by regular; a screen wider than 667 points - an iPhone 6 Plus in landscape, at 736 - is regular
horizontally. `-[UIScreen _updateUserInterfaceIdiom]` (0x24e86b4c) gives the main screen the device's idiom
and any other screen `-1`, unless it is a car's display, which is 3. So the collection of an external
display is idiom -1 with the size classes of its own size under the device's idiom: 1024 by 768 is regular by
regular, and 640 by 480 on a phone is compact by regular.

The backport reads the same two functions. Its main screen uses the size of `-[UIScreen bounds]`, which iOS 6
never rotates, swapped in a landscape interface orientation, and its other screens the size of their own
bounds; the answers are cached per orientation and are dropped when the bounds, the scale or the device's
idiom change. The device test checks the main screen's collection against the rule with the real bounds of
the device it runs on, the host test against seventeen combinations of idiom and size - the edges at 667 and
668, 479 and 480 among them - and both agree.

`-[UIScreen nativeBounds]` is the screen's reference size - the one that does not rotate, which is
`-bounds` on iOS 6 - multiplied by `-nativeScale`, at the origin; `-nativeScale` is the scale of any screen
but the main one, and for the main screen is worked out from the display's native size. The devices iOS 6
runs on have displays whose native size is the screen's size times its scale, so the two answers are
`bounds` times `scale` and `scale`, and the device test holds them to that on an iPhone 4S and an iPad 2.

## What a controller and a view answer

`-[UIViewController _parentTraitEnvironment]` in UIKit of iOS 8.0 (0x250ff574) names where a controller's
traits come from: its parent controller, else the presentation controller of the controller that presented
it, else the superview of its view, else its window. A view, likewise, takes them from its superview and so
up through the view of a controller, whose environment is the controller. What the newest system answers
is the same in the cases it can be asked without a running application, which is where a window would be
needed: a view that is in no window and a controller with no parent, no presenter and no view answer the
traits of the screen - the size classes above and the scale of the display, not an empty collection - and
a child controller answers its parent's traits merged with the override its parent has been given for it.

The backport takes the same four steps in the same order. For a presented controller it answers the
presenter's traits without a presentation controller between: iOS 6 has no adaptive presentation, so
that controller would only hand the presenter's traits on. The device test holds a presented controller to
its presenter's, a child to its parent's, the view of a child to what the child answers, and a controller
whose view has been added to another controller's to that controller's traits, override and all.

`-setOverrideTraitCollection:forChildViewController:` keeps the collection it is given for that child in the
parent that was asked, and `-overrideTraitCollectionForChildViewController:` answers that very object - not
a copy - to that parent, and nil to any other controller, to a controller never given one, and to nil.
Setting one for a nil child does nothing, and setting nil removes it, after which the child answers what
its parent does. The override outlives the child's removal from the parent and its return to it. In
iOS 8.0 the method also tells the child, through the private
`-_parent:willTransitionToTraitCollection:withTransitionCoordinator:`, that its parent is about to change
traits, and the backport has no counterpart of that call; what comes of it is the calls below.

`-traitCollectionDidChange:` reaches an environment when its traits changed and only then, with the traits
it had before: giving a child a compact override where it was regular calls the child once with the regular
ones, giving the same override again calls nothing, and giving a regular one over it calls once more.
Clearing an override that gave the traits the environment's own calls nothing. On iOS 6 the same happens
when the status bar turns: the screen, the windows and what is below them are asked, each with the traits
it had before the turn, and the device test holds the screen, a controller and a view to that.

## Where iOS 6 answers differently

The newest system lets an override given to a controller reach it through a parent it was not given
through: a controller with no parent whose override was set by another controller takes that override into
its traits, and a child given one override by each of two parents shows both. The backport keeps an
override in the parent that was asked and applies only the one of the parent the controller has, so both
of those answer the traits of the environment. It is reading one parent's storage as another's, which
nothing an application written to the documentation does.
