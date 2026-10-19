#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVFDescriptorConstruction.h"

@implementation AVCaptureBracketedStillImageSettings

- (float)charon_exposureTargetBias
{
    return [(NSNumber *)objc_getAssociatedObject(self, "charon.avf.bracket.exposureTargetBias") floatValue];
}

- (void)charon_setExposureTargetBias:(float)exposureTargetBias
{
    objc_setAssociatedObject(self, "charon.avf.bracket.exposureTargetBias",
                             @(exposureTargetBias), OBJC_ASSOCIATION_RETAIN);
}

- (CMTime)charon_exposureDuration
{
    NSValue *boxed = objc_getAssociatedObject(self, "charon.avf.bracket.exposureDuration");
    CMTime duration = kCMTimeZero;
    if (boxed) {
        [boxed getValue:&duration size:sizeof(duration)];
    }
    return duration;
}

- (void)charon_setExposureDuration:(CMTime)exposureDuration
{
    objc_setAssociatedObject(self, "charon.avf.bracket.exposureDuration",
                             [NSValue valueWithBytes:&exposureDuration objCType:@encode(CMTime)],
                             OBJC_ASSOCIATION_RETAIN);
}

- (float)charon_ISO
{
    return [(NSNumber *)objc_getAssociatedObject(self, "charon.avf.bracket.ISO") floatValue];
}

- (void)charon_setISO:(float)iso
{
    objc_setAssociatedObject(self, "charon.avf.bracket.ISO", @(iso), OBJC_ASSOCIATION_RETAIN);
}


- (instancetype)charon_initWithExposureTargetBias:(float)exposureTargetBias
                                   exposureDuration:(CMTime)exposureDuration
                                               ISO:(float)iso
{
    self = [super init];
    if (self) {
        [self charon_setExposureTargetBias:exposureTargetBias];
        [self charon_setExposureDuration:exposureDuration];
        [self charon_setISO:iso];
    }
    return self;
}

@end

@implementation AVCaptureAutoExposureBracketedStillImageSettings

- (float)exposureTargetBias
{
    return self.charon_exposureTargetBias;
}

+ (instancetype)autoExposureSettingsWithExposureTargetBias:(float)exposureTargetBias
{
    return [[self alloc] charon_initWithExposureTargetBias:exposureTargetBias
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
    return self.charon_exposureDuration;
}

- (float)ISO
{
    return self.charon_ISO;
}

+ (instancetype)manualExposureSettingsWithExposureDuration:(CMTime)exposureDuration ISO:(float)iso
{
    return [[self alloc] charon_initWithExposureTargetBias:0.0f
                                            exposureDuration:exposureDuration
                                                        ISO:iso];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVCaptureManualExposureBracketedStillImageSettings %p iso=%g>",
            self, (double)self.ISO];
}

@end
