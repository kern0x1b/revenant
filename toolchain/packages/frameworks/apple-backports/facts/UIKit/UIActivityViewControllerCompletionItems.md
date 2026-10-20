# UIActivityViewController.completionWithItemsHandler, iOS 8

Introduced in iOS 8.0, replacing `completionHandler` (iOS 6.0), which takes only the activity type and whether it completed.

The port keeps the block and puts a block into `completionHandler` that calls it with the type, the outcome, no returned items and
no error. Setting it to nil clears the release's handler too. What the release does not report - the items an action extension
returned, and the error - are nil, as they are for an activity that returns none; an action extension does not exist on iOS 6.
`device/smallapis.m` sets the handler, calls the release's own with a type and reads what arrives.
