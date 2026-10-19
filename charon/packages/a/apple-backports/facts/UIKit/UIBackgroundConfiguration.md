# UIBackgroundConfiguration, iOS 14.0

Seven styles (clear, plain, grouped and sidebar cell, header and footer, accompanied sidebar) and the fields a background is made of.

## What the port does as UIKit does
- Style colours and corner radii as measured; `updatedConfigurationForState:` for plain, grouped, sidebar and header styles. Colour, transformer, insets and corner radius that were set persist over a state change.
- The description prints the stroke only for a width above zero and a colour that is not clear, and "Custom" for a block.

## Differences
- The blur and shadow of a reordering row are not drawn, so the tests leave `reordering` out of the background updates.
- `image` (iOS 15) is kept by reference and `imageContentMode` as the value given, both carried by a copy as they were at the copy. Nothing
  draws the image, and neither is archived, so the host's archive of them was not compared.

## What the host measures that a phone would not

The host is Catalyst, so its metrics are those of the Mac idiom: row margins {15,16,15,8}, a plain row estimate of 40.04 (44 x 0.91), a sidebar inset of 12.987 (10 / 0.77), a corner radius of 26 for grouped and sidebar lists, some Mac colours. The port follows the host's raw values, except the row estimate of a list layout, which is 44, the phone's. Nothing here was measured on an iPhone; `Dynamic Light Alpha` was 0.12 in light and 0.4 in dark, and the port carries 0.12, since this release has no dark mode.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured with random values and states side by side with the port in one process, and the header of SDK 16.4. The differential tests are `tests/backports/host/uikit2` (the `listvalues` group for values, the windowed `listcell` group for views); the device application is `tests/backports/device/lists.m`, held to the numbers the host recorded in `lists-expectations.h`.
