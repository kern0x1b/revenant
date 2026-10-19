#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVFDescriptorConstruction.h"

// The bracketed still-image settings, iOS 8: the abstract base and its two concrete forms.
//
// The first HELD RUNG that exports these three classes and their metaclasses is **8.0**, measured over
// every held cache with _NSFileSize planted as a control; 4.3, 6.1.3 and 7.0 do not export them, and
// they are the releases the port's floor spans, so the port defines all three under Apple's own
// names.
//
// **What the host actually declares, which is what these are written against** (own methods, own
// properties, instance size):
//
//   AVCaptureBracketedStillImageSettings               -initSubclass only, size 8, superclass NSObject
//   …AutoExposureBracketedStillImageSettings          exposureTargetBias (float, R), superclass the
//                                                      base, size 16, and
//                                                      +autoExposureSettingsWithExposureTargetBias:
//   …ManualExposureBracketedStillImageSettings         exposureDuration (CMTime, R) and ISO (float,
//                                                      R), superclass the base, size 40, and
//                                                      +manualExposureSettingsWithExposureDuration:ISO:
//
// So the base is an abstract marker with no members of its own - the port defines the class and its
// Charon initializer and nothing else, because there is nothing else. An empty class of that name
// would satisfy every `isKindOfClass:` and answer no numbers at all, which is the shape this registry
// calls out; these two answer theirs.
//
// A bracketed settings object is plain configuration: it names an exposure bias, a duration and an
// ISO, and it means all three before a device is anywhere near it. That is what makes it carryable -
// nothing here needs a capture device, and the two class factories below are the header's own ways of
// making one.

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
    // CMTime is a struct, so it is boxed by its own bytes and read back the same way; NSValue has no
    // accessor for a CMTime and the first version of this asked it for one.
    NSValue *boxed = objc_getAssociatedObject(self, "charon.avf.bracket.exposureDuration");
    CMTime duration = kCMTimeZero;
    if (boxed) {
        [boxed getValue:&duration size:sizeof(duration)];
    }
    return duration;
}

- (void)charon_setExposureDuration:(CMTime)exposureDuration
{
    // CMTime has no NSValue boxing, so the two integers are boxed in one; the header's own struct.
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
