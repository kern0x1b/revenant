#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "RevenantAVFDescriptorConstruction.h"

@implementation AVCaptureBracketedStillImageSettings

- (float)revenant_exposureTargetBias
{
    return [(NSNumber *)objc_getAssociatedObject(self, "revenant.avf.bracket.exposureTargetBias") floatValue];
}

- (void)revenant_setExposureTargetBias:(float)exposureTargetBias
{
    objc_setAssociatedObject(self, "revenant.avf.bracket.exposureTargetBias",
                             @(exposureTargetBias), OBJC_ASSOCIATION_RETAIN);
}

- (CMTime)revenant_exposureDuration
{
    NSValue *boxed = objc_getAssociatedObject(self, "revenant.avf.bracket.exposureDuration");
    CMTime duration = kCMTimeZero;
    if (boxed) {
        [boxed getValue:&duration size:sizeof(duration)];
    }
    return duration;
}

- (void)revenant_setExposureDuration:(CMTime)exposureDuration
{
    objc_setAssociatedObject(self, "revenant.avf.bracket.exposureDuration",
                             [NSValue valueWithBytes:&exposureDuration objCType:@encode(CMTime)],
                             OBJC_ASSOCIATION_RETAIN);
}

- (float)revenant_ISO
{
    return [(NSNumber *)objc_getAssociatedObject(self, "revenant.avf.bracket.ISO") floatValue];
}

- (void)revenant_setISO:(float)iso
{
    objc_setAssociatedObject(self, "revenant.avf.bracket.ISO", @(iso), OBJC_ASSOCIATION_RETAIN);
}


- (instancetype)revenant_initWithExposureTargetBias:(float)exposureTargetBias
                                   exposureDuration:(CMTime)exposureDuration
                                               ISO:(float)iso
{
    self = [super init];
    if (self) {
        [self revenant_setExposureTargetBias:exposureTargetBias];
        [self revenant_setExposureDuration:exposureDuration];
        [self revenant_setISO:iso];
    }
    return self;
}

@end

@implementation AVCaptureAutoExposureBracketedStillImageSettings

- (float)exposureTargetBias
{
    return self.revenant_exposureTargetBias;
}

+ (instancetype)autoExposureSettingsWithExposureTargetBias:(float)exposureTargetBias
{
    return [[self alloc] revenant_initWithExposureTargetBias:exposureTargetBias
                                            exposureDuration:kCMTimeZero
                                                        ISO:0.0f];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVCaptureAutoExposureBracketedStillImageSettings %p bias=%g>",
            self, (double)self.exposureTargetBias];
}

@end

@implementation AVCaptureManualExposureBracketedStillImageSettings

- (CMTime)exposureDuration
{
    return self.revenant_exposureDuration;
}

- (float)ISO
{
    return self.revenant_ISO;
}

+ (instancetype)manualExposureSettingsWithExposureDuration:(CMTime)exposureDuration ISO:(float)iso
{
    return [[self alloc] revenant_initWithExposureTargetBias:0.0f
                                            exposureDuration:exposureDuration
                                                        ISO:iso];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVCaptureManualExposureBracketedStillImageSettings %p iso=%g>",
            self, (double)self.ISO];
}

@end
