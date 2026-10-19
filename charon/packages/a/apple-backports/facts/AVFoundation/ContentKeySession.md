# AVContentKeySession (10.3), AVContentKeyRequest (10.3) and AVContentKey (14.5)

What the port carries of the content key session, the request it hands the application and the key a recipient gets,
what the host measured, which of those answers the host does not repeat from run to run, and what the port does not
carry. The code is `AVFoundation/AVContentKeySession103.m`, `AVFoundation/AVContentKey145.m` and
`AVFoundation/AVContentKeyResponse103.m`; the measurements are `tests/backports/host/avf-contentkey-session`, which asks
the same questions of this Mac's AVFoundation (macOS 27.0.1) and of the port's classes in one binary, diffs the answers
line for line, and checks the port's decryption against a CommonCrypto oracle (`vectors.m`). The values the port's
decryption rests on are in `ContentKeyValues.md`.

## What the port carries

- `AVContentKeySession`, iOS 10.3, with `+contentKeySessionWithKeySystem:` (11.0) and the storage-directory initializer.
  Key systems: `AVContentKeySystemClearKey` (11.0), `AVContentKeySystemFairPlayStreaming` and
  `AVContentKeySystemAuthorizationToken` (13.0). The delegate, the delegate queue, the recipients, the key system, the
  storage URL, the protection session identifier, `processContentKeyRequestWithIdentifier:initializationData:options:`,
  `addContentKeyRecipient:`, `removeContentKeyRecipient:`, `expire`, the persistence, renewal and invalidation calls
  (refused as measured below), and the class methods on pending expired-session reports.
- `AVContentKeyRequest`, iOS 10.3: the status, error, identifier, initialization data, options, specifier,
  `processContentKeyResponse:`, `processContentKeyResponseError:`, `makeStreamingContentKeyRequestDataForApp:...`.
- `AVContentKey`, iOS 14.5: `contentKeySpecifier`, `externalContentProtectionStatus` (17.4) and `revoke` (17.4), and the
  port's own sample decryption (below). The session hands each recipient one key per request.
- The protocols `AVContentKeySessionDelegate` and `AVContentKeyRecipient`, forward-declared in
  `CharonAVFoundationProtocols.h` (the SDK defines them).

## Measured: the session

- A session for each of the three key systems reports the key system it was given, and a 16-byte protection session
  identifier.
- A key system no framework knows (`NoSuchSystem`) raises `NSInvalidArgumentException`:
  `*** -[AVContentKeySession initWithKeySystem:storageDirectoryAtURL:legacyWebKitCompatibilityMode:] input keySystem is not supported`.
- A storage directory is refused by ClearKey and by the token system, each with its own reason:
  `ClearKeySystem does not support storage URL` and `AuthorizationTokenSystem does not support storage URL`, with the
  same selector prefix. FairPlay accepts the directory, and its `storageURL` is the URL given. The port refuses the two
  systems with the same reasons and records the FairPlay URL as given. What the host writes into a FairPlay storage
  directory is not measured; the port writes nothing.
- The delegate the session reports is the one it was given.

## Measured: the request

- A request for initialization data `nil` is delivered once. Its status is RequestingResponse (0), its identifier is
  the one given, its initialization data is nil, and it has no content key (`contentKey` answers nil). Its options are
  `ProtocolVersionsKey` for FairPlay and empty for ClearKey and the token system. It answers `canProvidePersistableContentKey`
  NO and `renewsExpiringResponseData` NO on ClearKey.
- A request for non-nil initialization data made no callback (ClearKey, the one case measured).
- A delegate that implements `contentKeySession:didProvideContentKeyRequests:forInitializationData:` gets one batch of
  one request for nil data, and not the singular callback.
- The request's specifier carries the key system and the identifier as given.
- The key a recipient gets names the request's key system and identifier. The request's own `contentKey` answers nil.

## Measured: responses

- A ClearKey response with a 16-byte key and an 8- or 16-byte vector makes the request ReceivedResponse (1) with no
  error. The delegate's `contentKeyRequestDidSucceed:` and each recipient's `contentKeySession:didProvideContentKey:` then
  happen. The recipient gets an `AVContentKey` whose specifier is the request's, whose external protection status is
  Pending (0), and whose `revoke` answers without error.
- ClearKey accepts a key of 0, 4, 16 and 32 bytes at the response, with a 16-byte vector.
- ClearKey accepts a vector of 8 or 16 bytes only. Every length from 0 to 34 was asked in each of ten runs; 8 and 16 were
  accepted in every run and no other length was. A vector longer than 34 bytes is not measured; the port refuses it the
  same way as the other refused lengths.
- A token response makes the request ReceivedResponse (1) with no error, and the delegate hears it succeed.
- A FairPlay response with a payload that is not a key response makes the request Failed (5), and the delegate's
  `contentKeySession:contentKeyRequest:didFailWithError:` is called. The host's error shape varies (below).
- `processContentKeyResponseError:` with an error the application makes makes the request Failed (5) with that error,
  and the delegate hears that error.
- FairPlay streaming request data (`makeStreamingContentKeyRequestDataForApp:...`) answers
  `AVFoundationErrorDomain -11800`, with the underlying `NSOSStatusErrorDomain -42650` on FairPlay and `-19154` on ClearKey.
  The port answers the same. The token system's underlying status is not measured.
- Persistence and renewal refuse on ClearKey, each with the host's reason: `respondByRequestingPersistableContentKeyRequestAndReturnError:`
  raises `ClearKeySystem does not support key persistence`, `renewExpiringResponseDataForContentKeyRequest:` raises
  `ClearKeySystem does not support key renewal`, and `makeSecureTokenForExpirationDateOfPersistableContentKey:` and the
  two invalidate calls raise `ClearKeySystem does not support this operation`. The port raises the persistence refusal on
  every system (the FairPlay answer is not measured); the other paths are carried as the host answers them on ClearKey.
- `pendingExpiredSessionReportsWithAppIdentifier:storageDirectoryAtURL:` answers zero reports in an empty directory, and
  `removePendingExpiredSessionReports:` returns.

## The host's answers that vary from run to run

These are not compared on stdout by the probe. Stdout carries the stable part (the request is refused, the status), and
the shape goes to stderr as a measurement. The counts are from ten runs of the host probe, the same binary each time.

- The error of a refused clear key vector is one of two shapes, and which one the host gives changes between runs:
  `CoreMediaErrorDomain -12160`, or `AVFoundationErrorDomain -11800` with the underlying `NSOSStatusErrorDomain -12160`.
  Over the 33 refused lengths, ten runs each (330 refusals): 171 CoreMedia, 159 AVFoundation-wrapped. The same vector gave
  both shapes in different runs. The port gives the CoreMedia one.
- The error of a FairPlay response the port cannot use is `CoreMediaErrorDomain -12158` or `AVFoundationErrorDomain -11800`
  with the underlying `-12158`. For the same payload: 10 of 10 answers were CoreMedia on the singular callback, and 7 of
  10 were CoreMedia on the response; the rest were the wrapped form. The port gives CoreMedia.
- The order of `contentKeyRequestDidSucceed:` and the recipient's `didProvideContentKey:` is not fixed. Five runs: the
  delegate first in three, the recipient first in two. The port gives the delegate first. The probe prints both events
  sorted and records the order that happened on stderr.

## Named divergences

- The refused-response error shape (above): the port gives one of the host's two shapes for each refusal, because the
  host gives either.
- The order of the two success callbacks (above): the port gives one of the two orders.

## Not carried, and what it would take

- `-expire` on the session: an earlier probe found the host forwards it to the delegate, and that probe crashed. The
  call is not in the current probe, so the forwarding is not re-measured here. The port's `expire` answers without effect,
  since no persistable key is made; the host's effect on a persistable key is not measured.
- The persistable and renewal paths are refused by the port on every key system where the host does the same on
  ClearKey. What the host does on FairPlay for these is not measured.
- `makeStreamingContentKeyRequestData` on the token system: the underlying status is not measured.
- `originatingRecipient` (18.4) is not carried.
- The effect of `revoke` on a key a recipient holds: the call answers without error; whether the host stops the key
  working is not measured, so the port makes no change to the key.
- The token system's recipient behaviour: a token response gives no key to a recipient in the port, since the host's
  answer to a recipient on that system is not measured.
- A response of the wrong kind for the key system (a FairPlay response to a ClearKey request, and so on): the port
  refuses it with the FairPlay refusal; the host's answer is not measured.
- Mismatched responses, a request answered twice, and a response after the session is gone: not measured.
- The delegate queue when none is given: the port delivers on the main queue; the host's queue is not measured.
- A vector longer than 34 bytes: not measured.
- Decryption of a sample. The host has no public decryptor, so the port's CBC (16-byte vector, PKCS#7) and CTR (8-byte
  vector, counter from zero) are checked by `vectors.m` against CommonCrypto ECB with the chaining and the counter
  built by hand. That checks the port against a second implementation, not against the host. The FairPlay key is not
  decrypted here: the port answers the FairPlay response with the error above.

## Caveats

- The host test runs against macOS's Foundation and AVFoundation, not on the 6.1.3 device. The port's objects are plain
  Objective-C over `NSData` and `NSString`, and the device's Foundation decides the copies. That is not measured on a device.
- The storage behaviour and the refusal wording are macOS 27.0.1's. The 6.1.3 device may word them differently; the port
  uses the macOS wording.
