#import <SceneKit/SceneKit.h>
#import <objc/runtime.h>

static const char revenant_autoreverses_key;
static const char revenant_repeat_count_key;
static const char revenant_time_offset_key;
static const char revenant_duration_key;
static const char revenant_timing_mode_key;
static const char revenant_speed_key;

static BOOL revenant_SCNAction_autoreverses(id self, SEL _cmd)
{
    return [objc_getAssociatedObject(self, &revenant_autoreverses_key) boolValue];
}

static void revenant_SCNAction_setAutoreverses(id self, SEL _cmd, BOOL autoreverses)
{
    objc_setAssociatedObject(self, &revenant_autoreverses_key, @(autoreverses), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static CGFloat revenant_SCNAction_repeatCount(id self, SEL _cmd)
{
    return [objc_getAssociatedObject(self, &revenant_repeat_count_key) floatValue];
}

static void revenant_SCNAction_setRepeatCount(id self, SEL _cmd, CGFloat repeatCount)
{
    objc_setAssociatedObject(self, &revenant_repeat_count_key, @(repeatCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSTimeInterval revenant_SCNAction_timeOffset(id self, SEL _cmd)
{
    return [objc_getAssociatedObject(self, &revenant_time_offset_key) doubleValue];
}

static void revenant_SCNAction_setTimeOffset(id self, SEL _cmd, NSTimeInterval timeOffset)
{
    objc_setAssociatedObject(self, &revenant_time_offset_key, @(timeOffset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSTimeInterval revenant_SCNAction_duration(id self, SEL _cmd)
{
    return [objc_getAssociatedObject(self, &revenant_duration_key) doubleValue];
}

static void revenant_SCNAction_setDuration(id self, SEL _cmd, NSTimeInterval duration)
{
    objc_setAssociatedObject(self, &revenant_duration_key, @(duration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static SCNActionTimingMode revenant_SCNAction_timingMode(id self, SEL _cmd)
{
    return [objc_getAssociatedObject(self, &revenant_timing_mode_key) integerValue];
}

static void revenant_SCNAction_setTimingMode(id self, SEL _cmd, SCNActionTimingMode timingMode)
{
    objc_setAssociatedObject(self, &revenant_timing_mode_key, @(timingMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static float revenant_SCNAction_speed(id self, SEL _cmd)
{
    return [objc_getAssociatedObject(self, &revenant_speed_key) floatValue];
}

static void revenant_SCNAction_setSpeed(id self, SEL _cmd, float speed)
{
    objc_setAssociatedObject(self, &revenant_speed_key, @(speed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface RevenantSCNActionInstaller : NSObject
@end

@implementation RevenantSCNActionInstaller

+ (void)load
{
    Class cls = objc_getClass("SCNAction");
    if (!cls) {
        cls = objc_allocateClassPair(objc_getClass("NSObject"), "SCNAction", 0);
        if (cls) {
            objc_registerClassPair(cls);
        }
    }
    if (cls) {
        class_addMethod(cls, @selector(autoreverses), (IMP)revenant_SCNAction_autoreverses, "B@:");
        class_addMethod(cls, @selector(setAutoreverses:), (IMP)revenant_SCNAction_setAutoreverses, "v@:B");
        class_addMethod(cls, @selector(repeatCount), (IMP)revenant_SCNAction_repeatCount, "f@:");
        class_addMethod(cls, @selector(setRepeatCount:), (IMP)revenant_SCNAction_setRepeatCount, "v@:f");
        class_addMethod(cls, @selector(timeOffset), (IMP)revenant_SCNAction_timeOffset, "d@:");
        class_addMethod(cls, @selector(setTimeOffset:), (IMP)revenant_SCNAction_setTimeOffset, "v@:d");
        class_addMethod(cls, @selector(duration), (IMP)revenant_SCNAction_duration, "d@:");
        class_addMethod(cls, @selector(setDuration:), (IMP)revenant_SCNAction_setDuration, "v@:d");
        class_addMethod(cls, @selector(timingMode), (IMP)revenant_SCNAction_timingMode, "i@:");
        class_addMethod(cls, @selector(setTimingMode:), (IMP)revenant_SCNAction_setTimingMode, "v@:i");
        class_addMethod(cls, @selector(speed), (IMP)revenant_SCNAction_speed, "f@:");
        class_addMethod(cls, @selector(setSpeed:), (IMP)revenant_SCNAction_setSpeed, "v@:f");
    }
}

@end