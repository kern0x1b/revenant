# -[UIApplication beginBackgroundTaskWithName:expirationHandler:], iOS 7.1

Introduced in iOS 7.1: `-beginBackgroundTaskWithExpirationHandler:` with a name that shows in the debugger and in logs.

The release has the method without the name; the port calls it and drops the name (iOS 6 shows none). The identifier answered and the expiration handler are the release's own, and
`-endBackgroundTask:` ends it. `device/smallapis2.m` begins a task with and without a name and ends both.
