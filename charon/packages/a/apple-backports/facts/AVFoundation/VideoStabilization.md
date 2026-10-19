# Video stabilization: the format's support of iOS 7 and the modes of iOS 8

Rank 65 of the frameworks demand table: `AVCaptureConnection.preferredVideoStabilizationMode` and
`activeVideoStabilizationMode` (8.0), with `-[AVCaptureDeviceFormat isVideoStabilizationModeSupported:]`
(8.0) and `AVCaptureDeviceFormat.videoStabilizationSupported` (7.0) that they rest on. The armv7 cache
ladder first carries the two properties at 8.0; 6.0 already carries the connection's
`enablesVideoStabilizationWhenAvailable`, `videoStabilizationSupported` and `videoStabilizationEnabled`.

Source: the armv7 caches of 6.0, 6.1, 6.1.3, 7.0 and 8.0, the methods named here read from each
image's own class list and disassembled; an iPad 2 running 6.1.3 for what its cameras answer.

## What the releases do, read from their code

- 6.x: the connection keeps one switch, `enablesVideoStabilizationWhenAvailable`. Its setter raises
  `NSInvalidArgumentException` ("enablesVideoStabilizationWhenAvailable cannot be set because it is not
  supported by this connection.  Use -isVideoStabilizationSupported") unless `isVideoStabilizationSupported`,
  which is NO on a preview layer's connection and otherwise the source device's `stabilizationSupported`
  property. `videoStabilizationEnabled` is a second flag the capture pipeline sets.
  `AVCaptureDeviceFormat`, already a class of 6.0 with `activeFormat` and `formats` on the device, answers
  `-supportedStabilizationMethod` from the `SupportedStabilizationMethod` value of its dictionary; it has
  no public accessor for it.
- 7.0: `-[AVCaptureDeviceFormat supportedStabilizationMethod]` is `isVideoStabilizationSupported ? 2 : 0`,
  so 2 is the value of a format that stabilizes.
- 8.0: the connection keeps the preferred mode; `enablesVideoStabilizationWhenAvailable` answers
  "the preferred mode is Standard", and its setter (same exception and text when unsupported) sets the
  preferred mode to Standard or Off. `setPreferredVideoStabilizationMode:` raises
  `NSInvalidArgumentException` "Supplied preferredVideoStabilizationMode (%ld) is outside of the range of
  AVCaptureVideoStabilizationMode." outside Auto to Cinematic, and does not check support; the active mode
  is `-_resolveActiveVideoStabilizationMode:format:` of the preferred mode and the device's active format:
  Off unless the output is an `AVCaptureMovieFileOutput` or `AVCaptureVideoDataOutput`; Auto takes Standard
  and then Cinematic on a format whose last frame rate range runs faster than 60 frames a second, and
  Cinematic and then Standard otherwise, Off when the format has neither; any other mode is itself when
  the format supports it, else Off. `-[AVCaptureDeviceFormat isVideoStabilizationModeSupported:]` answers
  YES for any value past Cinematic and for Auto, and asks the capture source's format for the others:
  YES for Off, the format's `VideoStabilizationSupported` for Standard, and for Cinematic a flag no 6.x
  format dictionary has, on 1920 by 1080 formats only.

## What the port does

- `AVCaptureDeviceFormat.videoStabilizationSupported`: `-supportedStabilizationMethod == 2`, the inverse of
  7.0's own mapping. The release's method is called because it is the only reading of the format's
  stabilization the release has.
- `-isVideoStabilizationModeSupported:`: YES for Off and Auto, the format's support for Standard, NO for
  Cinematic, which 6.x does not do, and NO for the modes of later releases (8.0 answers YES there, as it
  predates them).
- `preferredVideoStabilizationMode` is kept on the connection together with the state it left the
  release's switch in; setting it resolves the mode as 8.0 does and turns the switch on when that gives
  Standard, off otherwise, on a connection that supports stabilization (the release raises for the switch
  elsewhere; 8.0 takes the mode there and resolves it to Off, which the switch left off gives). A value
  outside Auto to Cinematic raises 8.0's exception. Once the switch is set through the old property, the
  preferred mode is what 8.0 makes of that setter, Standard or Off.
- `activeVideoStabilizationMode` is Standard when the release says it stabilizes (`videoStabilizationEnabled`),
  Off otherwise: the release has one kind of stabilization, the one 8.0 maps its switch to.

## Differs

- The old `enablesVideoStabilizationWhenAvailable` is the release's own: after Auto resolves to Standard
  it answers YES, where 8.0 answers NO for any preferred mode but Standard.
- 8.0 sets the active mode when the preferred mode is set; the port reads what the release runs.
