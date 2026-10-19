# The temporary directory as a URL, iOS 10

Introduced in iOS 10.0: `-[NSFileManager temporaryDirectory]`.

Source: Foundation of the armv7s cache of iOS 10.3.4 and the host's own Foundation (`host/blocks`); the device test
`blocks.m` holds iOS 6 to the same answer.

It is `+[NSURL fileURLWithPath:isDirectory:]` with `NSTemporaryDirectory()` and YES. The URL is a file URL of the
application's temporary folder, with a slash at the end of its string. It is made afresh at each call.
