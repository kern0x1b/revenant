# Security names that iOS 6 already exports

The SDK dates some Security names after iOS 6, and asked one by one with `dlsym` after every framework of the
release was loaded, iOS 6 exports five of them. They are the release's own and are not carried here.

Source: an iPad 2 running 6.1.3 and the iOS 6.0 emulator.

## What the release exports

`SecCertificateCopyPublicKey`, `SecCertificateCopySerialNumber`, `SecPolicyCreateRevocation`,
`kSecPropertyTypeError` and `kSecPropertyTypeTitle`. What they do was not compared with a newer release: the names
are exported, and nothing more is claimed.

## Since which release

Security exports all five from 3.1.3.

The registry's `introduced` is the first release on the armv7 cache ladder (3.1.3 to 10.3.4) whose
library the SDK puts the name in exports it (`dyld.exported_at` with `dyld.sdk_owners`, the measure the gate
takes), not the SDK header's date; 3.1.3 is the lowest rung held, so it means "3.1.3 or earlier". The same pass
gives `kCGColorSpaceDisplayP3` 9.3 as the control, so the ladder does not answer its lowest rung for everything.
