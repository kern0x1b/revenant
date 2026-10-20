# UIConfigurationState, UIViewConfigurationState and UICellConfigurationState, iOS 14.0

The value a cell or view hands to the configuration handler: selected, highlighted, disabled, focused, the trait collection and, for a cell, editing, expanded, swiped, reordering and the drag and drop states. The protocols `UIConfigurationState` and `UIContentConfiguration` and `UIContentView` are compile time only and have no entry.

## What the port does as UIKit does
- Equality, hash, copy, `NSSecureCoding` and the description, with "Not Targeted" and "Targeted" for the drag and drop states and `Custom = {...}` printed only when a custom state exists (the trait collection's key order is random and is masked in the tests).
- `initWithTraitCollection:nil` raises NSInternalInconsistencyException, "Invalid parameter not satisfying: traitCollection != nil".
- Custom states are kept by key, through `customStateForKey:` and subscripting.

## What the port does not answer
- `isPinned` (iOS 15) is kept as the flag it is, NO by default and YES once set, and is part of equality and the hash. The description
  does not print it. The host's equality and description for a pinned state were not compared.

## What the host measures that a phone would not

The host is Catalyst, so its metrics are those of the Mac idiom: row margins {15,16,15,8}, a plain row estimate of 40.04 (44 x 0.91), a sidebar inset of 12.987 (10 / 0.77), a corner radius of 26 for grouped and sidebar lists, some Mac colours. The port follows the host's raw values, except the row estimate of a list layout, which is 44, the phone's. Nothing here was measured on an iPhone; `Dynamic Light Alpha` was 0.12 in light and 0.4 in dark, and the port carries 0.12, since this release has no dark mode.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured with random values and states side by side with the port in one process, and the header of SDK 16.4. The differential tests are `tests/backports/host/uikit2` (the `listvalues` group for values, the windowed `listcell` group for views); the device application is `tests/backports/device/lists.m`, held to the numbers the host recorded in `lists-expectations.h`.
