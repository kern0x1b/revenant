# The cache and the credential storage, told about a task, iOS 8.0 and 7.0

Nine rows: the three `NSURLCache` methods that take a data task, and the six `NSURLCredentialStorage`
methods that take one.

Source: the SDK 26.2 headers; the host's own `NSURLCache` for the three (measured: a stored response
reads back, `-removeCachedResponseForRequest:` takes it away, and
`-removeCachedResponsesSinceDate:` keeps a response that is newer than the date given).

**The cache.** Each of the three is the release's own request-shaped method with the task's request:
the task's `currentRequest` is what it is sending now and its `originalRequest` is what it started
with, and a task with neither is ignored. What the cache then stores and when it drops it are the
release's own answers, so a port that kept a cache of its own would be guessing where Apple's evicts.

**The credential storage.** On a release whose credential storage has no notion of a task, a task
argument is only ever nil or a task the application is holding, and a credential belongs to its
protection space either way -- so each of the six is the release's own method with the task's space.
`getCredentialsForProtectionSpace:task:completionHandler:` is the release's
`-credentialsForProtectionSpace:` under the name the newer API has. The options dictionary of
`-removeCredential:forProtectionSpace:options:` is where `NSURLCredentialStorageRemoveSynchronizableCredentials`
lives; 6.1.3 has no synchronizable credentials, so that option is read and has nothing to remove.

The host's own Catalyst headers predate this half of the credential API, so these six are held by
`tests/backports/device/foundation15batch.m` on the device and not by a host differential.
