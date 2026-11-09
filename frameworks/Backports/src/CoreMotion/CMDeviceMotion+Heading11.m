#import <CoreMotion/CoreMotion.h>
#import <objc/runtime.h>
#import "RevenantMotionHeading.h"

static const char revenant_motion_frame_key;

static BOOL revenant_north_frame(CMAttitudeReferenceFrame frame)
{
    return frame == CMAttitudeReferenceFrameXMagneticNorthZVertical || frame == CMAttitudeReferenceFrameXTrueNorthZVertical;
}

__attribute__((visibility("hidden")))
void RevenantTagDeviceMotion(CMDeviceMotion *motion, CMAttitudeReferenceFrame frame)
{
    if (!motion) {
        return;
    }
    NSNumber *current = objc_getAssociatedObject(motion, &revenant_motion_frame_key);
    if (current && (CMAttitudeReferenceFrame)current.unsignedIntegerValue == frame) {
        return;
    }
    objc_setAssociatedObject(motion, &revenant_motion_frame_key, @(frame), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation CMDeviceMotion (RevenantHeading11)

- (double)heading
{
    NSNumber *frame = objc_getAssociatedObject(self, &revenant_motion_frame_key);
    if (!frame || !revenant_north_frame((CMAttitudeReferenceFrame)frame.unsignedIntegerValue)) {
        return -1.0;
    }
    CMRotationMatrix m = self.attitude.rotationMatrix;
    return RevenantMotionHeadingDegrees(m.m21, m.m22, m.m23, m.m31, m.m32, m.m33);
}

@end

typedef __attribute__((ns_returns_retained)) id (*RevenantCopyFunction)(id, SEL, NSZone *);

static RevenantCopyFunction revenant_original_copy;

__attribute__((ns_returns_retained))
static id revenant_tagged_copy(CMDeviceMotion *motion, SEL command, NSZone *zone)
{
    id copy = revenant_original_copy(motion, command, zone);
    NSNumber *frame = objc_getAssociatedObject(motion, &revenant_motion_frame_key);
    if (copy && frame) {
        objc_setAssociatedObject(copy, &revenant_motion_frame_key, frame, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return copy;
}

static void revenant_wrap(Class cls, SEL selector, id (^make)(IMP original))
{
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        return;
    }
    class_replaceMethod(cls, selector, imp_implementationWithBlock(make(method_getImplementation(method))), method_getTypeEncoding(method));
}

@interface RevenantMotionHeadingInstaller : NSObject
@end

@implementation RevenantMotionHeadingInstaller

+ (void)load
{
    SEL start = @selector(startDeviceMotionUpdatesUsingReferenceFrame:toQueue:withHandler:);
    revenant_wrap([CMMotionManager class], start, ^id(IMP original) {
        return ^(CMMotionManager *manager, CMAttitudeReferenceFrame frame, NSOperationQueue *queue, CMDeviceMotionHandler handler) {
            CMDeviceMotionHandler tagged = nil;
            if (handler) {
                tagged = ^(CMDeviceMotion *motion, NSError *error) {
                    RevenantTagDeviceMotion(motion, frame);
                    handler(motion, error);
                };
            }
            ((void (*)(id, SEL, CMAttitudeReferenceFrame, NSOperationQueue *, CMDeviceMotionHandler))original)(manager, start, frame, queue, tagged);
        };
    });
    SEL poll = @selector(deviceMotion);
    revenant_wrap([CMMotionManager class], poll, ^id(IMP original) {
        return ^CMDeviceMotion *(CMMotionManager *manager) {
            CMDeviceMotion *motion = ((CMDeviceMotion * (*)(id, SEL))original)(manager, poll);
            RevenantTagDeviceMotion(motion, manager.attitudeReferenceFrame);
            return motion;
        };
    });
    SEL copying = @selector(copyWithZone:);
    Method copy = class_getInstanceMethod([CMDeviceMotion class], copying);
    if (copy && !revenant_original_copy) {
        revenant_original_copy = (RevenantCopyFunction)method_getImplementation(copy);
        class_replaceMethod([CMDeviceMotion class], copying, (IMP)revenant_tagged_copy, method_getTypeEncoding(copy));
    }
}

@end
