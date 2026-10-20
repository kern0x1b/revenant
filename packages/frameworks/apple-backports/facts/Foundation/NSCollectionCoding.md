# Secure decoding of collections, iOS 14

decodeArrayOfObjectsOfClass(es):forKey: and the dictionary forms, and the unarchivedArray / unarchivedDictionary class methods.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The checks are in the order the host makes them: the container class first, then each element against the allowed classes, with the same error codes. The unarchiver methods require secure coding and unwrap the root key.
