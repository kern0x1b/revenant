# UIProgressView.observedProgress, iOS 9

Introduced in iOS 9.0: a progress view is handed an `NSProgress` and follows it, so nothing in the application has
to copy `fractionCompleted` into `progress` by hand.

Source: **the release's own implementation, not a host differential.** The host is no oracle here and that is worth
saying plainly: under Mac Catalyst the system's own `UIProgressView` does not move at all when it is given an
observed progress - recorded over four runs, `progress` stays at whatever it was while `fractionCompleted` goes from
0.2 to 0.7 - so what the host shows is the absence of an answer, not an answer. What was read instead is
`-[UIProgressView setObservedProgress:]` in the armv7 cache of iOS 9.3.5, at 0x25358fa1, and the selectors its
image refers to.

## What the release does

- `-setObservedProgress:` retains its argument, asks it whether it is equal to the progress the view already holds,
  and returns at once when it is. So setting the same progress twice is a no-op, and the comparison is `-isEqual:`
  rather than pointer identity - which for `NSProgress`, which overrides neither `-isEqual:` nor `-hash`, is the
  same thing.
- It then releases the observation it had and builds a block; UIKit 9.3.5 refers to `fractionCompleted` and to
  `-addObserver:forKeyPath:options:context:`, and `UIProgressView` itself implements neither
  `-observeValueForKeyPath:ofObject:change:context:` nor `-dealloc`, so the observation is key-value observing
  through a helper and not through the view.

## What the port does

The port observes `fractionCompleted` of the progress with a helper of its own, `CharonProgressObserver`, which
holds the view weakly and the progress strongly and removes its observation when it is deallocated - so a progress
view that goes away while observing takes the observation with it and does not leave key-value observing pointing
at freed memory. A change seen off the main thread is applied on the main queue, since `NSProgress` publishes from
whichever thread moved it and a view may only be touched on the main one.

Two things the reading does not settle, decided here and named for what they are:

- The port applies the fraction **at once** when the progress is assigned, by observing with
  `NSKeyValueObservingOptionInitial`. Neither the host nor the disassembly says whether the release does; a
  property whose whole point is that the bar shows the progress would be useless if the bar stayed stale until the
  next move, so the port takes it at once.
- The port sets `progress` **without animating**. iOS 9 has `-_setProgressAnimated:duration:delay:options:` beside
  the plain setter and the reading does not say which the observation uses, so the port takes the one whose effect
  it can be sure of. A bar that follows a progress therefore jumps where the release may glide.

Setting `progress` by hand while an observation is in place is allowed and is not undone until the progress next
moves, which is then what wins; the observation is not dropped by it. Clearing the observed progress stops the
following and leaves the bar where it stood. `device/observedprogress.m` holds all of that on iOS 6, and asks
`dladdr` that both accessors come from `libUIKitBackports.dylib`.

## What the device run shows

`device/observedprogress.m` on an emulated iOS 6.0 (iPhone3,1, 10A403): eighteen checks, no failures. Both
accessors come from `libUIKitBackports.dylib`; the fraction is taken at once on assignment; the bar follows the
progress; a value set by hand stands until the progress next moves and does not drop the observation; setting the
same progress again changes nothing; a second progress replaces the first and the first stops moving the bar;
clearing the observation leaves the bar where it stood; and a progress view that is deallocated while observing
takes its observation with it, with no complaint from key-value observing when the progress moves afterwards.
