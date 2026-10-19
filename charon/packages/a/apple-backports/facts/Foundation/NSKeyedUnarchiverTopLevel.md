# NSKeyedUnarchiver unarchiveTopLevelObjectWithData:error:

Source: the host's own Foundation, held against the backport by the `archiving.topLevel*` records of
`tests/backports/host/foundation2/run.sh`; and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad 2,
through `tests/backports/device/foundation2.m`.

`+unarchiveTopLevelObjectWithData:error:` answers the top-level object of a keyed archive, the one archived under
the root key, and sets the error to nil. An array of a string, a number and a date archived with
`archivedDataWithRootObject:` comes back as the same array, and the error is nil.

Data that is not an archive answers nil. The newest release does not set an error for it, and the port does not
either: the record for `junk` holds nil and no error on both. That is the reason for taking the top level this way
and not from `+unarchivedObjectOfClass:fromData:error:`, which reports `4864` for the same data
(`NSKeyedUnarchiver.md`); the two methods are not told apart by the class check only.
