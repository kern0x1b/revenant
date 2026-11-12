# The default background of a `UILabel` on iOS 6

A `UILabel` made in code has an opaque white background on iOS 6. On iOS 7 and later it has none. The backports give the label the later
default.

## What was seen

Measured on an iPhone 4S, iOS 6.1.3, with an injected probe: `[[UILabel alloc] init]`, `initWithFrame:` and `[UILabel new]` all
answer `backgroundColor` = white (gray 1, alpha 1) with `opaque` YES; a plain `UIView` answers `nil` and `opaque` YES. `UILabel`
implements `initWithFrame:` and `initWithCoder:` itself and does not implement `init`, so `init` ends in `initWithFrame:`.

Telegram's country list puts a `UILabel()` with the dialling code in each row's `accessoryView`. On the grey row the code was drawn
on a white rectangle ("+93", "+355", ...).

## What the backports do

`UILabel+Background7.m` replaces `-[UILabel initWithFrame:]` on a system older than iOS 7. After the original initialiser it looks at
the label's background: when it is the default white (a gray or RGB colour with every component 1, see `RevenantLabelBackground.m`)
it sets `backgroundColor` to `nil` and `opaque` to NO, as iOS 7 has it. Another colour or a translucent white is the application's
and stays. A label loaded from a nib keeps what the nib says (`initWithCoder:` is not touched), and a background an application sets
after the initialiser is its own.

An application written for iOS 6 that relied on the default white (a label on a coloured view, meant to show white) sees a
transparent label; the backports exist for applications built for the later behaviour.

## Tests

`frameworks/Backports/tests/UIKit/label_background_test.m` (host, target `UIKitBackports_label_background_test`) checks the decision:
gray and RGB white at full alpha are the default; a grey, a translucent white, clear, black, a tinted white, three components and
no components are not. 11 checks, and the negative run fails. The initialiser swap ran on the phone (Telegram's country list after the
deb of this change).
