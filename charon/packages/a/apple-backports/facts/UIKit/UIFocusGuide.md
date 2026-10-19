# UIFocusGuide, iOS 9

Introduced in iOS 9.0 as a `UILayoutGuide` whose frame the focus engine reads: a focus move across it goes to
`preferredFocusedView`, or, from iOS 10, to the first of `preferredFocusEnvironments` that can take focus.
`enabled` turns the guide on and off. The SDK 16.4 header is the contract: `enabled` (9.0), `preferredFocusedView`
(9.0, deprecated at 10.0), `preferredFocusEnvironments` (10.0).

The release has no focus engine, so nothing ever reads a guide. The class is carried so that an application can
create one, set its properties and read them back, and the values are kept exactly as set.

## Defaults, measured on the host

A probe on Mac Catalyst (`UIFocusGuide` alloc/init):

- the superclass is `UILayoutGuide`;
- `enabled` is YES; setting NO reads back NO;
- `preferredFocusedView` is nil; a set view reads back the same object, and nil clears it;
- `preferredFocusEnvironments` is an empty array, not nil;
- `layoutFrame` is `CGRectZero` and `owningView` is nil, both inherited from `UILayoutGuide`.

The port's code is written to these defaults; no port-side run has checked them yet. `preferredFocusedView` is weak,
as the header declares.

## What is not carried

The focus engine never runs on iOS 6, so no focus move ever consults a guide. An application that sets a guide
gets its own values back and nothing else. Encoding a guide is not measured here, so `initWithCoder:` takes the
inherited layout guide state and resets the three properties to the host defaults.

## Device

Not run on a device. Behaviour here is the stored values and their defaults, which the host answers. A device run
for a guide that a focus engine does consult is the one that would show a difference, and there is no such engine on
iOS 6.
