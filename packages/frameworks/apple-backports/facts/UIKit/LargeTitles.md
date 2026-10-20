# Large titles of a navigation bar

`UINavigationBar.prefersLargeTitles`, `UINavigationBar.largeTitleTextAttributes` and `UINavigationItem.largeTitleDisplayMode` are stored by the
release in the bar and the item and read by the bar's layout, which draws a second, tall title row and collapses it as a scroll view moves.

Source: UIKit of iOS 12.0 arm64 (each accessor read at its address in the cache: plain stores of an instance variable, the bar's copying
its attributes), and the host's own UIKit under Mac Catalyst, recorded by `tests/backports/host/homeindicator/run.sh` and held against the port
on the iPad 2 by `tests/backports/device/homeindicator.m`.

## What the port does

The three properties answer what was set, with the release's defaults: no large titles, no attributes, and the automatic mode. The attributes are
copied when set. The bar keeps its one title row and its look: a large title is not drawn, and the bar's height is what this release measures, which is
also what the safe area and the adjusted content inset of a scroll view under it are measured from.

Not carried: the second row itself, its collapse under a scrolling view, and `+largeTitle` fonts as drawn by the bar.
