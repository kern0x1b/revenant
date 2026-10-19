# Appearances on the bars of iOS 6, iOS 13

Source: the public SDK headers of iOS 13 to 27; the host's own UIKit, under Mac Catalyst, for what a bar hands back
(`tests/backports/host/uikit2/appearances_test.m`: the defaults, the copies, clearing, and, through the legacy
accessors of the host's bars, what the port sets); and the iOS 6 calls the port maps them onto, which the device test
cannot exercise, since it makes no views.

## The properties

`UINavigationBar` and `UIToolbar` answer `standardAppearance`, `compactAppearance`, `scrollEdgeAppearance` and
`compactScrollEdgeAppearance`; `UITabBar` answers `standardAppearance` and `scrollEdgeAppearance`; `UINavigationItem` the
four and `UITabBarItem` the two. All are applied. Which appearance a bar shows is chosen as the SDK's own comment on
`UINavigationBar.standardAppearance` says, and the same for the other bars with what they lack left out:

| state | first that is set, in this order |
|---|---|
| normal size, not at the edge | top item's standard, bar's standard |
| compact size, not at the edge | top item's compact, bar's compact, then the normal size's |
| at the edge | top item's scroll edge, bar's scroll edge, then the normal size's |
| compact at the edge | top item's compact scroll edge, bar's compact scroll edge, top item's scroll edge, bar's scroll edge, top item's compact, bar's compact, then the normal size's |

The normal size goes on `UIBarMetricsDefault` and the compact size on `UIBarMetricsLandscapePhone`; with nothing set for
the compact size the landscape metrics are cleared and show the default image. The top item of a tab bar is its selected
item. When nothing is set at the edge, the standard appearance is used, the way the coordinator asked for; the SDK says
"a modified standardAppearance" and the iOS 13 look of that is a transparent one, which the port does not draw.

**The edge.** The content scroll view of a bar is the first scroll view found, breadth first and not inside another
bar, in the view of the view controller the bar belongs to: the controller whose view holds the bar, then down through a
navigation controller's top view controller and a tab bar controller's selected one. A navigation bar is at the edge
when `contentOffset.y + adjustedContentInset.top <= 0.5`; a tab bar and a toolbar when the bottom of the content is in
view, `contentOffset.y + bounds.height - adjustedContentInset.bottom >= contentSize.height - 0.5`. A bar with no scroll
view, or whose controller has not loaded its view, is at the edge, as it is in iOS 15 and later. The port watches
`contentOffset`, `contentSize` and `contentInset` of that scroll view by key-value observing and re-chooses only when the
answer to "at the edge" changes, so nothing is redrawn while a table scrolls; the observation is dropped when the bar's
content scroll view or top item changes, and when the bar goes.

**The item.** UIKit is reached at four places, since a `UINavigationController` may call the bar in more than one way:
`pushNavigationItem:animated:`, `popNavigationItemAnimated:` and `setItems:animated:` of the navigation bar, `setSelectedItem:`
and `setItems:animated:` of the tab bar, and `layoutSubviews` and `didMoveToWindow` of all three, which a push, a pop and
a selection all cause. Each re-chooses once at once and once on the next turn of the run loop, when a pushed controller has
loaded its view, and does nothing when the choice is the same as the last, so the bar changes when the item does and
never twice. Setting an appearance on the top item, or changing the one it keeps, is applied at once.

The methods are replaced only in a process where the appearance classes are the backports': they are not on a release that
has them.

What the host answers, and the backport answers as well:

- `standardAppearance` is never nil: a bar that was never given one answers a new appearance of its own kind, the same
  object every time. Setting nil brings that default back. The others answer nil until set.
- A setter keeps a copy of what it is given, and the getter answers that copy, so a change to the object handed in
  changes nothing and a change to the object handed back is a change to the bar.
- An object of the wrong kind is kept and applied to nothing, where the host raises nothing either.
- A tab bar answers no compact appearance.

## When an appearance is applied

The setters apply at once. A change made later to the appearance a bar keeps, through the object the getter
handed back, is applied on the next turn of the run loop, once for any number of changes. The default appearance
a bar hands back is applied only when it is changed, so reading it changes nothing. Setting nil takes back what an
earlier appearance applied.

The bar's legacy calls are the ones the appearance is mapped onto. An application that uses both has the
appearance win, as in iOS 13, since the appearance is applied whole: what it does not set is cleared.

## The map

| appearance | iOS 6 |
|---|---|
| `backgroundImage` | `setBackgroundImage:forBarMetrics:` of the bar, as it is; the content mode is kept and ignored |
| `backgroundColor`, no image | a one point image of the colour, stretched, through the same call |
| no image, no colour, no effect (the transparent and the new navigation bar look) | an empty image, so the bar is clear |
| the default effect, no image, no colour | nothing: the bar keeps the look iOS 6 gives it; the blur is ignored |
| `shadowImage` | `shadowImage` of the bar; with a background image or colour applied only, since iOS 6 draws no shadow otherwise |
| `shadowColor`, no image | a hairline of the colour, one pixel tall, as the shadow; nil is an empty image, no shadow |
| `titleTextAttributes` (navigation) | `titleTextAttributes` of the bar, the font and colour and the shadow of an `NSShadow` turned into the `UITextAttribute` keys of iOS 6; every other key is dropped |
| `titlePositionAdjustment` (navigation) | `setTitleVerticalPositionAdjustment:forBarMetrics:`; the horizontal part has no counterpart |
| `compactAppearance` | the same, for `UIBarMetricsLandscapePhone`; without one the metrics are cleared and the standard image shows |
| `buttonAppearance` | on `UIBarButtonItem appearanceWhenContainedIn:` the bar's class: the title text attributes of the normal, highlighted and disabled states when they differ from the defaults, the title offset of the normal state, the plain background image of each state |
| `doneButtonAppearance`, `prominentButtonAppearance` | the background images of the done style; its text attributes are not applied, since iOS 6 has one set per state for both styles |
| `backButtonAppearance` | `setBackButtonBackgroundImage:forState:barMetrics:` and the back button's title offset; its title attributes are those of the plain button |
| tab bar `selectionIndicatorImage` | `selectionIndicatorImage` of the tab bar |
| tab bar stacked `selected.iconColor` | `selectedImageTintColor` |
| tab bar stacked `normal` and `selected` title attributes, and the normal title offset | `UITabBarItem appearanceWhenContainedIn:` the tab bar, states normal and selected |

The buttons are set on the appearance proxy of a bar's class, since iOS 6 has no button setting for one bar: they reach
every bar of that class in the application, and only views that come into a window afterwards. A program that sets an appearance
on one navigation bar of several gets the button look on all of them.

## Kept in the object and not applied

- `backgroundEffect` blur, of any style; `backgroundImageContentMode`; the compact shadow, since iOS 6 has one shadow
  for a bar.
- `largeTitleTextAttributes` (says once in the log), the horizontal title offset, the back indicator images
  (`inert`, as on the bar itself since iOS 7's `backIndicatorImage`), the focused state of every button, the position
  adjustments of a background image, and the text attributes of the prominent button.
- On a tab bar (says once in the log): the icon colour of an unselected tab, the badge appearance, the inline and
  compact inline layouts, `selectionIndicatorTintColor` and the positioning, width and spacing of the items.
- `barTintColor`, which the port carries for iOS 7, is not touched.

## Unsure, to be proved on a device

The legacy proxies of iOS 6 are checked for when a view enters a window, so an appearance set after a bar is on
screen may not reach the buttons already there until they leave and return. Reading the proxy back, the host's UIKit
answers what was set; that iOS 6's answers the same has not been read.
