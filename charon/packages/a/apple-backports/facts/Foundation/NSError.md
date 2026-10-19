# NSError, the user info key of iOS 11.0

`NSLocalizedFailureErrorKey` (the string `NSLocalizedFailure`) arrived in iOS
11.0: a sentence naming what failed, which `-localizedDescription` puts in front
of the reason.

Source: the host's Foundation.

## Behaviour

iOS 11 builds `-localizedDescription` in this order (`NSError.h`): the
`NSLocalizedDescriptionKey` of the user info as it is; the failure of the user
info, followed by the reason; the provider's description
(`+setUserInfoValueProviderForDomain:provider:`); the provider's failure,
followed by the reason; then what the releases before did (the reason with a
generic sentence, or a string made from the domain and code). The reason is
`-localizedFailureReason`: the user info's, then the provider's, then the one
the release generates for the domain and code. Failure and reason are joined by
a space.

Measured on the host's Foundation:

- failure and reason: `The file could not be saved. The disk is full.`;
- the failure alone, domain `charon`: `Only the failure.`;
- the failure alone, `NSCocoaErrorDomain` `4`: `Only the failure. The file
  doesn’t exist.` (the reason the release generates);
- with `NSLocalizedDescriptionKey` as well: that description;
- an error made by `CFErrorCreate` with failure and reason: the same sentence as
  the first, from `-localizedDescription` and from `CFErrorCopyDescription`;
- a provider answering a description, a failure and a reason: the failure of the
  user info with the provider's reason (`Own failure. Provided reason.`) wins
  over the provider's description; the provider's description wins over its
  failure; the provider's failure takes the reason of the user info when there
  is one, and stands alone when nothing gives a reason.

## What the port carries

The key, exported under its own string `NSLocalizedFailure`, and what iOS 11
does with it: `Foundation/NSLocalizedFailureErrorKey.m` wraps `-[NSError
localizedDescription]` on a release whose Foundation does not export the key
(`dlsym` on the loaded Foundation) and answers the two failure steps above,
leaving the others to the release. Below iOS 9 the provider's steps are
`NSError+UserInfoValueProvider.m`'s wrapper, installed from `+load`; the failure
wrapper has to sit outside it, since the failure of the user info comes before
the provider's description, so it is installed from a constructor, which runs
after every `+load` of the library.

Without the key an application that names it does not get a poorer message, it
gets no key at all: a strong import is a missing symbol and dyld stops the
application at launch (Delta imports it that way), and a weak import reads
`NULL`.

## Where 6.1.3 answers differently, measured on an iPad 2

`tests/backports/device/tail11.m`, this library through `DYLD_LIBRARY_PATH`:
every case above answers as on the host, and an error made by `CFErrorCreate`
(a `__NSCFError`) takes the same method, except for two answers that do not come
from the key:

- iOS 6 generates no failure reason for a code of `NSCocoaErrorDomain`:
  `-localizedFailureReason` of `NSCocoaErrorDomain` `4` is `nil`, and without a
  failure its description is `The operation couldn’t be completed. (Cocoa error
  4.)`. With the failure alone the description is therefore `Only the failure.`,
  where the host, whose release generates `The file doesn’t exist.`, appends that
  reason. The reasons of Cocoa codes are a behaviour of `-localizedFailureReason`
  in later releases, not of this key.
- `CFErrorCopyDescription` is a C function of CoreFoundation, which does not
  call `-localizedDescription`: for failure and reason it answers `The operation
  couldn’t be completed. The disk is full.`, where the host answers the failure
  sentence. The release has no public way to change what a C function of
  another library answers. `kCFErrorLocalizedFailureKey`, the CoreFoundation
  name of the key, is not in the registry.
