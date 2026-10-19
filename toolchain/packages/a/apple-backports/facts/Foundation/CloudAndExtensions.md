# The names of iCloud metadata and app extensions, the deallocator blocks and file access intents, iOS 7 to 10

Source: the host's own Foundation for every value and every answer, recorded by `host/foundation8b` from
`device/foundation8b-cases.m` and read again on the iPhone 4S by `device/foundation8b.m`; the SDK headers for the release each name
arrived in; the shared caches of iOS 6.0 to 10 for what the release exports.

## The names

The iCloud metadata keys and values (`NSMetadataUbiquitousItem…`, the query update keys and the content type keys) are the strings
of the system. The release's metadata query has no iCloud scope of iOS 7 to fill them in, so no item carries them and they are
`inert`. The four host notifications of an app extension (`NSExtensionHost…`) are strings that nothing posts: the release has no app
extension and so no host. `NSExtensionMain` is the entry point an extension's executable names; on the release there is no
host to run it for, so it says so on the error stream and answers 69 (`inert`).

## NSDataDeallocator

The four blocks for `-initWithBytesNoCopy:length:deallocator:` free the bytes the way their names say: virtual memory,
an unmapping and `free`; the fourth, `NSDataDeallocatorNone`, is `nil`, as the system's is - a data given no deallocator frees nothing.

## NSFileAccessIntent and the coordination of intents

An intent names a URL and whether it is read or written, with the coordination options, and answers the URL to use in the
accessor - the one the coordination arrived at, which may not be the one it was made with. `-[NSFileCoordinator
coordinateAccessWithIntents:queue:byAccessor:]` waits on a background queue for each intent in turn with the synchronous
coordination the release has since iOS 5, nested so that every item is held together, and runs the accessor on the queue
it was given with no error, keeping the items held until it returns. When coordination fails the accessor runs with the error
and nothing is held.
