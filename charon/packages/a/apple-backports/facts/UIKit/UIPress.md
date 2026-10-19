# UIPress, UIPressesEvent, the responder messages of presses and UICollectionViewTransitionLayout

Source: the host's own UIKit under Mac Catalyst, in an application with a window, asked for each answer below and held
against the backport by `tests/backports/host/presses/run.sh`, eight records that the app `tests/backports/device/presses.m`
compares on a device running 6.1.3.

## UIPress and UIPressesEvent, iOS 9.0

A press is a button of a remote, a game controller or a hardware keyboard. The release has none of them and sends no such
event, so both classes only exist.

- A press made by `-init` has phase began (0), type up arrow (0), no window, no responder, no recognizers and force 0. The
  superclass is NSObject. The values of the types (up, down, left, right arrows, select, menu, play/pause: 0 to 6) and of the
  five phases (0 to 4) are those of the header.
- `UIPressesEvent` is a `UIEvent` of type presses (3) whose `allPresses` and `pressesForGestureRecognizer:` are empty sets.
- `UIPress.key`, an iOS 13.4 property, is nil: a press has no hardware key, since the release never sends a press from a keyboard. A fresh press
  answers nil, as the host does (`tests/backports/host/press-key`, 3 checks, with the port's answer diffed against the host's; a planted press that
  answers an object fails).
- `-[UIResponder pressesBegan:withEvent:]`, `pressesChanged:`, `pressesEnded:` and `pressesCancelled:` hand a **non-empty** set
  to the next responder and do nothing for an empty one, so an override that calls `super` reaches the responder after it.
  The release never sends the messages; an application that calls them, or an override that calls `super`, is safe.

## UICollectionViewTransitionLayout, iOS 7.0

The layout a collection view puts in place while it moves from one layout to another, with the two layouts and the
progress between them. The release's collection view lays out through the invalidation context but has no such
animation, so the port drives the transition itself; see [CollectionViewTransition.md](CollectionViewTransition.md),
which carries the whole of it. What is left here is what the release alone decides.

- `-initWithCurrentLayout:nextLayout:` keeps the two layouts as they are given; the progress is 0 and can be set.
- The superclass is `UICollectionViewLayout`.
- `-updateValue:forAnimatedKey:` and `-valueForAnimatedKey:` keep nothing outside a running transition: the host
  answers 0 for every key, before and after an update, and the update moves nothing. The device case
  `transition.set` in `presses-cases.m` records `progress=0.5 value=0.0 other=0.0` after setting the progress to 0.5
  and updating a key to 0.7, and both the port and `presses-expectations.h` answer exactly that. The port's own
  transition drives the progress through the `transitionProgress` property instead, so nothing in it needs the keys
  to store.
