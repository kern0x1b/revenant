# The navigation bar on a gesture, and the two scroll views

## The bar hiding on a swipe or a tap (iOS 8)

The release's navigation controller has no such gesture: the bar is there until a push or a pop
changes it. The port adds the two gestures the header names, and the four flags that say which of
them hides the bar.

**Every default here was measured, and three of them were not what I expected:**

- `hidesBarsOnSwipe`, `hidesBarsOnTap`, `hidesBarsWhenKeyboardAppears` and
  `hidesBarsWhenVerticallyCompact` are all **NO** in a navigation stack made by hand. The natural
  assumption is that iOS 8 turned the swipe on by default, and it is not: the host answers `no` for
  all four (`tests/backports/host/uikitscroll`, the `nav.*Default` cases). A port that guessed YES
  would hide the bar on every stack in every application, which is the kind of quiet wrong answer
  this project exists to not give.
- `barHideOnSwipeGestureRecognizer` is **not** the interactive pop. Asking the host for
  `barHideOnSwipeGestureRecognizer` and for `interactivePopGestureRecognizer` gives two different
  recognisers (`nav.swipeIsThePopGesture` records `different`). My first attempt reused the pop
  gesture on the reasoning that one finger at the edge should not drive two things; the host has two
  recognisers and so does this, each deciding for itself.
- The two recognisers are **private classes on the host** — `_UIBarPanGestureRecognizer` and
  `_UIBarTapGestureRecognizer` — which this port may not name. It uses the public
  `UIScreenEdgePanGestureRecognizer` and `UITapGestureRecognizer` and behaves the same. That is the
  one place this family's answers differ from the host's, and it is recorded as the two cases
  `nav.swipeGestureKind.diverges` and `nav.tapGestureKind.diverges`, which assert the port's own
  kinds: they fail if the host ever stops diverging, and they fail if the port ever starts naming a
  private class.

**The trait path is the real one.** `hidesBarsWhenVerticallyCompact` reads
`traitCollection.verticalSizeClass` and is re-applied by wrapping the release's own
`-traitCollectionDidChange:`, keeping the original implementation and calling it — the same way
`UINavigationController+InteractivePop.m` wraps `-viewDidLoad`. My first attempt drove it from
`UIContentSizeCategoryDidChangeNotification`, which is a different event: a vertical size class
change arrives through the trait collection and the layout pass, and that draft was thrown away for
it.

The keyboard is observed with `addObserver:selector:name:object:` and unobserved with the matching
`removeObserver:`, the way `UISheetPresentationController.m` does it, so turning the flag off really
stops the bar moving and the observer does not hold the controller. The first attempt used blocks
that were never removed and captured the controller strongly.

## The separators, and how the port draws an inset one

The release draws a table's separator inside the cell's own drawing and offers no way to move it. It
does, however, draw **none at all** when the table's `separatorStyle` is `None` — the release's own
answer for a table with no separator. So the port takes the separator over the release's way round:
when a table or a cell asks for anything that is not the default, the port sets that style to `None`
for that table only, remembering what it was, and draws the separator in a view of its own inside each
cell at the inset that was asked for, in the table's own `separatorColor` and `separatorStyle`.
`cellLayoutMarginsFollowReadableWidth` insets that view by the table's own `layoutMargins`, and
`separatorEffect` goes behind the line rather than replacing it. Putting every value back at its
default gives the release its separator back, so **a table with nothing set looks exactly as it did**.

The geometry is the host's, measured, not chosen: the style default is `1` (SingleLine), the colour
default is set, the table's `layoutMargins` are `{8, 8, 8, 8}` and the screen's scale is 2. The
insets are the host's too — the table's is `{0, 16, 0, 0}` and a cell's own is `{0, 8, 0, 8}`, so a
port starting either at zero would put every separator in the wrong place. The **line height** is the
release's own one-point separator, which is what iOS 6.1.3 draws; the host draws a hairline, and the
host's height is not what this port copies, because the port is drawing for the release, not for the
host.

The double-line style is reached by the value it had, not by a name: the port's header is SDK 26.2,
which removed `UITableViewCellSeparatorStyleDoubleLine` in iOS 13, so an application compiled against
these headers cannot ask for it either.

## The delegate questions the release never asks

`UICollectionViewDelegate`'s two `willDisplay…` questions and the three estimated-height questions on
`UITableViewDelegate` are asked by the release on no code path, so an application that implemented
them was never called. Now:

- the two `willDisplay…` questions are asked from the layout pass that puts an element on screen,
  **once per element** — remembered, so a layout pass that runs again for the same cell does not ask
  a second time, which a delegate that configures a cell as it arrives would notice;
- the three estimated heights are asked where the port genuinely needs the distance: deciding how many
  rows are about to come on screen in `UITableView+Prefetching10.m`, which until now used a fixed
  three rows either side. That use is real and the answers change the geometry.

**What the port cannot give:** the release's own scrolling does not consult the estimated heights, so
they inform this port's decisions and not the release's scroll indicator. There is no public seam
for the release's estimation, and this is recorded rather than papered over.

## Still not built in this family

`UICollectionView.prefetchDataSource` and `prefetchingEnabled` and the two prefetching protocols'
methods are built (group 3). Remaining and measured: the two `UINavigationControllerDelegate`
orientation questions, whose defaults with no delegate are neither portrait nor all.
