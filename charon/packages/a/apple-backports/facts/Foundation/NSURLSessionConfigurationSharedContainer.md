# NSURLSessionConfiguration.sharedContainerIdentifier, iOS 8

Introduced in iOS 8.0: the app group whose container a background session puts its downloaded files in, so that an application and its extensions see the same ones.

Source: the host's own Foundation under Mac Catalyst (`host/tail3/run.sh`): a configuration has none, holds one that is set and gives it back, cleared with `nil`; a copy has it and is independent of the original; a background configuration
holds one beside its identifier; a session made from the configuration keeps it. `device/tail3.m` repeats them on iOS 6.

## How the port does it

The identifier is kept with the configuration and copied with it, and nothing uses it: the release has no app extensions to share a container with, and the transfers of a session stay in the application's own container. On a
release whose own class copies a configuration (iOS 7), a copy made by the release does not carry the identifier.
