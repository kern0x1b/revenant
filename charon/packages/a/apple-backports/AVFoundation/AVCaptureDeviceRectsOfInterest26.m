// AVCaptureDeviceRectsOfInterest26.m - the eight members of iOS 26's rectangles of interest, answered the way
// Apple's own devices without the machinery answer them.
//
// WHAT CHANGED, and why, in one place. An earlier version of this object answered -isFocusRectOfInterestSupported
// and -isExposureRectOfInterestSupported with the release's own point-of-interest support, kept the rectangle
// and applied its centre through the release's own -setFocusPointOfInterest: (which is what the header says a
// rectangle does, :1171), and so answered YES on a device that could weigh nothing but a point. That was wrong,
// and the coordinator's ruling says why in the terms this file now uses: **a device that honours only the
// rectangle's centre does not support rectangles of interest**, and the host's own camera - whose support flag
// is 0 - answers every one of these eight members the way a device without the machinery does. So:
//
//   * the two support flags answer NO, always, and that is a hardware answer rather than a shrug: the release
//     cannot weigh an area. 6.1.3's AVCaptureDevice owns -isFocusPointOfInterestSupported,
//     -focusPointOfInterest, -setFocusPointOfInterest: and the exposure pair (measured,
//     tools/corpus/objc-inventory.lua over the 6.1.3 armv7 cache) and NO focus area, no metering area and no
//     sensor size anywhere - so there is nothing on this release that could weigh a rectangle, whatever a
//     device reported about a point. Measured on the host, whose camera supports neither: 0 and 0.
//   * the two minimum sizes answer { 0, 0 }, which is the header's own value for a device that does not support
//     the rectangle (:1167, :1411) and what the host answers.
//   * the two rectangles answer CGRectNull, measured on the host for both.
//   * the two default-rectangle methods answer CGRectNull, which is what the header says this method returns
//     when the device does not support the rectangle (:1184, :1429) and what the host answers for every point
//     tried - measured at (0.5, 0.5), (0, 0), (0.75, 0.75) and (1, 1), CGRectIsNull 1 each time.
//   * the two setters refuse in the order Apple's own refuses, and the order is measured: an unlocked send
//     raises NSGenericException even on a device whose support flag is 0, so the configuration lock is checked
//     first and the support flag second.
//
// SO NOTHING IS KEPT. The earlier version kept a rectangle per device in an associated object, reconciled it
// against the release's point of interest (the header's own reset rule, :1171) and had a size check. With no
// support there is no rectangle to keep, no reset to reconcile and no size to check - a setter that refuses
// every value cannot have a last accepted one - and code that stores a value nothing can reach is the silent
// fake this tree forbids. The two static keys, the two geometry helpers and the reset are gone, and the
// harness's plants for them with them.
//
// The refusal texts: the lock one is Apple's own, measured on the host as "*** -[AVCaptureDALDevice
// setFocusRectOfInterest:] May not be called without first successfully gaining exclusive ownership of the
// device using -lockForConfiguration:", and this port's own is worded the way the other lock refusals of this
// package are (AVCaptureDevice+ActiveFrameDuration.m, whose texts the release itself uses). The support one is
// Apple's own tail with this port's class in the prefix, because AVCaptureDALDevice is a private class of
// Apple's device-access layer that this port does not have, while the setter belongs to AVCaptureDevice - the
// class the port has and the header declares the member on.
#import "CharonAVCaptureDeviceRectsOfInterest26.h"

// The release's own lock reader, which is not in any public header but is a method of the release's own
// AVCaptureDevice at 5.1.1, 6.0, 6.1 and 6.1.3 (the configuration lock count above 0) and is what every public
// setter of 6.1.3's camera device asks before it does anything else. The same seam, and the same reason for it,
// as packages/a/apple-backports/AVFoundation/AVCaptureDevice+VideoZoom7.m and AVCaptureDevice+ActiveFrameDuration.m.
@interface AVCaptureDevice (CharonReleaseLock)
- (BOOL)isLockedForConfiguration;
@end

// The two refusals of one setter, in the order Apple's own raises them (measured on this host). The selector
// is a parameter so that the same two functions serve the focus setter and the exposure setter, whose selector
// names differ in the text Apple prints.
static void charon_rect_refused_without_lock(NSString *name)
{
    [NSException raise:NSGenericException
                format:@"%@ cannot be set without first successfully gaining exclusive ownership of the device"
                       @" using -lockForConfiguration:", name];
}

static void charon_rect_refused_unsupported(NSString *property, NSString *support)
{
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDevice set%@:] Not supported - use -is%@", property, support];
}

@implementation AVCaptureDevice (CharonCaptureDeviceRectsOfInterest26)

- (BOOL)isFocusRectOfInterestSupported
{
    return NO;
}

- (CGSize)minFocusRectOfInterestSize
{
    return CGSizeZero;
}

- (CGRect)focusRectOfInterest
{
    return CGRectNull;
}

- (CGRect)defaultRectForFocusPointOfInterest:(CGPoint)pointOfInterest
{
    return CGRectNull;
}

- (void)setFocusRectOfInterest:(CGRect)focusRectOfInterest
{
    if (![self isLockedForConfiguration])
        charon_rect_refused_without_lock(@"focusRectOfInterest");
    charon_rect_refused_unsupported(@"FocusRectOfInterest", @"FocusRectOfInterestSupported");
}

- (BOOL)isExposureRectOfInterestSupported
{
    return NO;
}

- (CGSize)minExposureRectOfInterestSize
{
    return CGSizeZero;
}

- (CGRect)exposureRectOfInterest
{
    return CGRectNull;
}

- (CGRect)defaultRectForExposurePointOfInterest:(CGPoint)pointOfInterest
{
    return CGRectNull;
}

- (void)setExposureRectOfInterest:(CGRect)exposureRectOfInterest
{
    if (![self isLockedForConfiguration])
        charon_rect_refused_without_lock(@"exposureRectOfInterest");
    charon_rect_refused_unsupported(@"ExposureRectOfInterest", @"ExposureRectOfInterestSupported");
}

@end