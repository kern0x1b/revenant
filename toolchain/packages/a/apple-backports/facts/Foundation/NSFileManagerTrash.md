# Moving an item to the trash, iOS 11.0

Introduced in iOS 11.0 on iOS: `-trashItemAtURL:resultingItemURL:error:` moves an
item to the trash and says where it went.

Source: an iPad 2 running 6.1.3, and Foundation of the arm64 shared cache of iOS
12.0, `-[NSFileManager trashItemAtURL:resultingItemURL:error:]` at `0x18192b958`.

## What iOS 6 answers

The release already has the method: `instancesRespondToSelector:` answers YES, the
code being one OS X and iOS share. Called on a file the process wrote to its temporary
directory it answers **NO** with no resulting URL and an error in
`NSCocoaErrorDomain` with code **3328**, the feature unsupported error, and the file
is still where it was.

## What iOS 12 does

The method checks its URL argument, then hands the URL and the two out-parameters to a
private method of the file manager and, when that fails and an error is wanted, builds
an error of its own with the item's path. What the private method does was not read
to its end, so what iOS 11 answers for an item in the application's sandbox is not
said here.

## What the package does

Nothing: the call reaches the release's own method, so the entry is `ignored`. An
application that moves an item to the trash and reads the error learns that it
could not; one that ignores the result finds the item still there.
