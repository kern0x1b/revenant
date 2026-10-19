# NSUserDefaults with a suite, iOS 7

Introduced in iOS 7.0: `-[NSUserDefaults initWithSuiteName:]`, the defaults of a named domain rather than the application's own.

Source: the host's own Foundation, run beside the port through Mac Catalyst (`host/suitedefaults/run.sh`): 50 answers of a suite
that the release makes and of the one the port makes, over typed reads of values of other types (a string that is a number, a
number read as a string, a boolean read from a string), URLs, arrays, dictionaries, data, registered defaults and what they yield
after a removal, the dictionary representation, the change notification and a second instance reading what the first wrote.
`device/suitedefaults.m` holds iOS 6 to them.

The release has `-initWithUser:` only, and its instances read and write the application's domain. The port answers an instance of a
subclass that keeps its values in the suite's own preferences domain (`Library/Preferences/<suite>.plist` in the application's data),
reads what it registered next, converts as the release does - a string is a boolean only for `yes`, `true` and `1` in any case, a
number is a string through its description - and posts `NSUserDefaultsDidChangeNotification`. The application's own identifier and
the global domain give nil, as the release does; no name gives the application's own defaults. A value that is not a property
list raises `NSInvalidArgumentException`: the host's release aborts the process instead, which the recorder cannot compare.

## What differs

A suite of the release is also searched in the global domain and shared by the applications of a group; the port's is neither, as
iOS 6 has no group container. Changes another process makes are not announced.
