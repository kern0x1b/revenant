# The ubiquity attributes of a file presenter, iOS 11.0

Introduced in iOS 11.0: a file presenter can name the ubiquity attributes it wants to
hear about (`observedPresentedItemUbiquityAttributes`), and is called with
`-presentedItemDidChangeUbiquityAttributes:` when one of them changes, after the
file coordinator that made the change reported it with
`-itemAtURL:didChangeUbiquityAttributes:`.

Source: the SDK 16.4 header `NSFilePresenter.h` and `NSFileCoordinator.h`. Nothing was
read from a release: iCloud document syncing of iOS 6 reports no change of these
attributes to a presenter, and a coordinator that is asked to report one has no method
for it.

- The presenter's property and its callback are `ignored`: the protocol is declared by
  the header and its metadata is compiled into the application, and the release never
  sends the callback.
- `-[NSFileCoordinator itemAtURL:didChangeUbiquityAttributes:]` is what an application
  calls, and the release has no such method: it is `absent`, so `respondsToSelector:`
  answers honestly and an unchecked call raises.
