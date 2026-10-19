#import "RevenantAVCaptureDeviceRectsOfInterest26.h"

@interface AVCaptureDevice (RevenantReleaseLock)
- (BOOL)isLockedForConfiguration;
@end

static void revenant_rect_refused_without_lock(NSString *name)
{
    [NSException raise:NSGenericException
                format:@"%@ cannot be set without first successfully gaining exclusive ownership of the device"
                       @" using -lockForConfiguration:", name];
}

static void revenant_rect_refused_unsupported(NSString *property, NSString *support)
{
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDevice set%@:] Not supported - use -is%@", property, support];
}

@implementation AVCaptureDevice (RevenantCaptureDeviceRectsOfInterest26)

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
        revenant_rect_refused_without_lock(@"focusRectOfInterest");
    revenant_rect_refused_unsupported(@"FocusRectOfInterest", @"FocusRectOfInterestSupported");
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
        revenant_rect_refused_without_lock(@"exposureRectOfInterest");
    revenant_rect_refused_unsupported(@"ExposureRectOfInterest", @"ExposureRectOfInterestSupported");
}

@end
