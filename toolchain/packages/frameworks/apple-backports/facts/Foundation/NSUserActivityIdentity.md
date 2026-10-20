# A user activity's own two members, iOS 11.0 and 12.0

`referrerURL` and `persistentIdentifier`. `NSUserActivity.m` declares both `@dynamic` and implements
neither, which is the shape that reads as missing and is not an implementation.

- The **referrer** is the URL the activity arrived from, kept as it is set.
- The **persistent identifier** is the string that names this activity in a store of saved activities.
  The port keeps one per activity and hands it back unchanged. It keeps no store of its own: the
  release's Handoff daemon has the only such store there is, and no entry point of it reaches an
  application, so `+deleteAllSavedUserActivitiesWithCompletionHandler:` has nothing it could delete
  without reporting a success it has not earned -- that row is `absent`, with the reason in
  `NSDecidedRows.md`.
