# selectionFollowsFocus of the list views (iOS 14)

`UICollectionView.selectionFollowsFocus` and `UITableView.selectionFollowsFocus` are properties of the iOS 14 SDK. Both are
built by `UIKit/UICollectionView+SelectionFocus14.m` and `UIKit/UITableView+SelectionFocus14.m`, one category each.

The release has neither property: the 6.1.3 inventory (`tools/corpus/objc-inventory.lua`) has no `selectionFollowsFocus` on
`UICollectionView` or `UITableView` (zero matches in the 12549-line inventory of 6.1.3), so the port adds them as iOS 14 API.

Host answers (macOS 27.0, Mac Catalyst, the `prefixed_windowed_expected focus` group of `tests/backports/host/uikit2`):

    collection default NO
    collection set YES YES
    collection set NO NO
    table default NO
    table set YES YES
    table set NO NO

So the default is NO, and a value set is read back as set. The port answers the same on the same calls, and the group checks
that its selector is the app's own implementation on both classes.

On iOS 6 nothing moves the selection with focus, because the release has no focus engine. The value is kept and read back, and
setting YES says once in the log that the selection does not follow focus.
