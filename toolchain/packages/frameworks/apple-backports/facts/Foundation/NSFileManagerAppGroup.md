# The container of an application group, iOS 7

Introduced in iOS 7.0: `-[NSFileManager containerURLForSecurityApplicationGroupIdentifier:]`, the folder that the applications
of one team share under a group identifier from their entitlements.

Source: the host's own Foundation, run beside the port through Mac Catalyst (`host/appgroup/run.sh`): 20 identifiers, among them
plain ones, a slash, a colon, a backslash, every punctuation mark of ASCII, accented Latin letters, Japanese, a combining mark, an
emoji, spaces and case. The system's answers become `device/appgroup-expectations.h`, and `device/appgroup.m` holds iOS 6 to
them on the iPhone 4S and the iPad 2.

## What the port does as the system does

An empty identifier, or none, answers nil. The folder is `Library/Group Containers/<name>` under the home of the application,
the URL is a file URL of a directory, and the same identifier gives the same URL. The name is the identifier with each character
it does not keep replaced by a hyphen: the release keeps ASCII letters and digits, the space, the hyphen, the full stop and the
underscore, and turns the rest - the slash, the colon, the backslash, every other punctuation mark, the characters of other
scripts, a combining mark, and each code point of an emoji - into one hyphen. A Latin letter with an accent is kept as its
base letter (`é` is `e`, `ü` is `u`).

## What differs

iOS 6 has no shared container: a sandbox holds one application's files, and the entitlement of a group means nothing to it.
The folder the port answers is in the application's own data, so applications of one group do not see one another's files;
an application that shares files with itself, or with a widget or an extension that iOS 6 does not have, finds what it wrote.
The release answers nil for a group the application's entitlements do not name, and the port answers a folder for any
identifier, so an application that was built without the entitlement keeps working. The port makes the folder, as the release does
on iOS; the Mac the recorder runs on does not, which is a difference of the recorder, not of the release. A letter whose accent
Apple's own table maps to more than one letter or to something that is not a base letter (`æ` to `ae`, `ß` to `s`, `©` to `-C-`)
is a hyphen in the port.
