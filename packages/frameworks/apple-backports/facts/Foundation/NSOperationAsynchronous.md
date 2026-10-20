# An operation's name and whether it is asynchronous, iOS 7.0 and 8.0

Source: the SDK 26.2 headers. The release's `NSOperation` has the getter of `-isAsynchronous` and no
setter, and no name at all.

Both are kept beside the operation. The name is the string that names the operation in a queue's list
and in a control, copied on the way in. The flag is the flag is: an operation that runs on a queue of
its own rather than in the queue's thread, which is what `NSOperationQueue` reads when it decides how
to run an operation -- so a value set here is what a queue sees.

Where nothing of ours is set, `-isAsynchronous` answers the release's own value, reached through the
superclass's implementation (a category's `[super]` would be `NSObject`'s).
