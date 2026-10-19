# UIListContentView, iOS 14.0

The view that draws a UIListContentConfiguration: two labels and an image view, and three layout guides.

## What the port does as UIKit does
- Layout by `sizeThatFits:` in the device's pixel grid (`ceil(x*scale)/scale`), the image slot rules (reserved size wins, then the maximum, then the region), side by side text decided from natural widths, a minimum height (40.04 for cell, subtitle and value styles, 33.88 for sidebar styles), superview margins inherited by `axesPreservingSuperviewLayoutMargins`.
- The guides are created when first asked and pinned with constraints.

## Tolerances of the differential test
- Labels of two or three lines and side by side rows of unlike fonts: 20 and 5 points in the height. The fitting size is not compared when the text is attributed, the lines are limited or a maximum size is set.
- Empty strings are not reproduced.

## What the host measures that a phone would not

The host is Catalyst, so its metrics are those of the Mac idiom: row margins {15,16,15,8}, a plain row estimate of 40.04 (44 x 0.91), a sidebar inset of 12.987 (10 / 0.77), a corner radius of 26 for grouped and sidebar lists, some Mac colours. The port follows the host's raw values, except the row estimate of a list layout, which is 44, the phone's. Nothing here was measured on an iPhone; `Dynamic Light Alpha` was 0.12 in light and 0.4 in dark, and the port carries 0.12, since this release has no dark mode.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured with random values and states side by side with the port in one process, and the header of SDK 16.4. The differential tests are `tests/backports/host/uikit2` (the `listvalues` group for values, the windowed `listcell` group for views); the device application is `tests/backports/device/lists.m`, held to the numbers the host recorded in `lists-expectations.h`.
