# AVFoundation release 8 demand rows

Corpus: `DEMAND-AVFoundation-8.tsv`, 4 rows, CRASH-ON-USE, each called by 1 app in the corpus.
`xmake l tools/cache-index/first-rung.lua setExposureTargetBias:completionHandler: setSessionWithNoConnection: maxExposureTargetBias minExposureTargetBias`
answers 8.0 for all four.

`objc.inventory` (`modules/apple/objc.lua`) over `~/.charon/dyld/6.1.3/dyld_shared_cache_armv7`,
`AVCaptureDevice`, selectors matching `exposure`/`bias`/`iso`:

    -setManualExposureSupportEnabled:  -exposureGain          -setExposureGain:
    -setExposureMode:                  -isManualExposureSupportEnabled
    -exposureDuration                  -exposureMode          -isExposurePointOfInterestSupported
    -setExposurePointOfInterest:       -setExposureDuration:  -isAdjustingExposure
    -isExposureModeSupported:          -exposurePointOfInterest
    -setAutoExposureBias:              -autoExposureBias      -isOpen

None of these is a public SDK name; the same query over `~/.charon/dyld/8.0/dyld_shared_cache_armv7`
answers `-maxExposureTargetBias`, `-exposureTargetBias`, `-minExposureTargetBias`,
`-setExposureTargetBias:completionHandler:` - the public quartet 8.0 adds over what 6.1.3 already had
privately. Filtered for `bias` alone on 6.1.3, only `-setAutoExposureBias:`/`-autoExposureBias` answer:
no bounds accessor of any name exists there, public or private.

`-setExposureTargetBias:completionHandler:` and `-setSessionWithNoConnection:` are implemented in
AVFoundationDemand8.m, driving the measured private pair and the always-available `-setSession:`
respectively. `maxExposureTargetBias`/`minExposureTargetBias` are left `absent`: the measurement above
is the proof that 6.1.3 has no bounds of any kind to read, and no SDK header or public source gives a
sensor's legal AE-bias range (there is no public source for AVFoundation internals at all, per this
project's own audit).
