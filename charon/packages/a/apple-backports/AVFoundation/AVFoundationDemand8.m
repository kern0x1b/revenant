#import "CharonAVCapture.h"
#import <objc/runtime.h>

// AVFoundation's 8.0 surface, two of the four rows DEMAND-AVFoundation-8.tsv measured CRASH-ON-USE
// against 6.1.3. ONE OBJECT for 8.0 only.
//
// -setExposureTargetBias:completionHandler: has no public or documented equivalent in 6.1.3's camera
// stack (iOS 6's AVCaptureDevice has no exposure-target-bias concept at all; custom/manual exposure
// control is itself an 8.0 arrival). But 6.1.3 is not silent on exposure: objc.inventory over
// ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 finds AVCaptureDevice already carries a private
// -autoExposureBias / -setAutoExposureBias: pair (and -exposureGain, -exposureDuration,
// -exposureMode, all private there too) - the same armv7 inventory over ~/.charon/dyld/8.0 shows the
// public trio (-exposureTargetBias, -minExposureTargetBias, -maxExposureTargetBias,
// -setExposureTargetBias:completionHandler:) replacing it. There is no public mechanism to drive, so
// this is the private one the rule allows, with the measurement above as the proof it has no public
// alternative.
//
// minExposureTargetBias and maxExposureTargetBias are NOT implemented here: 6.1.3's private pair has
// no bounds accessor of any kind (the same inventory query for "bias" on AVCaptureDevice finds only
// the getter and setter, nothing naming a range), there is no SDK header or public source for the
// legal range of a 6.1.3-era sensor's AE bias (facts/AVFoundation/AVFoundationOwed.md and this
// project's own "no public source exists for ... AVFoundation"), and discovering it by probing the
// private setter would mutate a device's live exposure from inside what must be a side-effect-free
// property getter - not a faithful port of a getter's contract. So the setter below passes the
// caller's value straight to the private driver and lets it clamp as it already does for its own
// -setAutoExposureBias: callers, rather than this port inventing a bound to clamp against itself.

@interface AVCaptureDevice (CharonPrivateExposure8)
- (float)autoExposureBias;
- (void)setAutoExposureBias:(float)bias;
@end

@interface AVCaptureDevice (CharonReleaseLock8)
- (BOOL)isLockedForConfiguration;
@end

@implementation AVCaptureDevice (CharonExposureTargetBias8)

- (void)setExposureTargetBias:(float)bias completionHandler:(void (^)(CMTime syncTime))handler
{
    if (![self isLockedForConfiguration])
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"You must call lockForConfiguration: before calling setExposureTargetBias:completionHandler:"
                                     userInfo:nil];
    [self setAutoExposureBias:bias];
    if (handler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(CMClockGetTime(CMClockGetHostTimeClock()));
        });
    }
}

@end

// -setSession: already forms the one connection 6.1.3's preview layer knows how to form (automatic
// video routing predates 8.0); -addConnection:/-canAddConnection: on AVCaptureSession, which is what a
// caller would use after -setSessionWithNoConnection: to wire a connection by hand, is itself an
// 8.0 arrival this port does not carry, so the "no connection" half of the contract has nothing to be
// built on. What real callers of this selector get on 6.1.3 is what they would have gotten from
// -setSession: - a working preview - rather than a crash.
@implementation AVCaptureVideoPreviewLayer (CharonSessionWithNoConnection8)

- (void)setSessionWithNoConnection:(AVCaptureSession *)session
{
    self.session = session;
}

@end
