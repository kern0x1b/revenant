#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>

@protocol LElement <NSObject>
@property (readonly) id collection;
@property (readonly) NSSet *aliases;
@property (readonly, getter=isAnalog) BOOL analog;
@property (readonly, getter=isBoundToSystemGesture) BOOL boundToSystemGesture;
@property (readonly) NSInteger preferredSystemGestureState;
@property (readonly) NSString *sfSymbolsName;
@property (readonly) NSString *localizedName;
@property (readonly) NSString *unmappedSfSymbolsName;
@property (readonly) NSString *unmappedLocalizedName;
@end

@protocol LButton <LElement>
@property (readonly) float value;
@property (readonly, getter=isPressed) BOOL pressed;
@property (readonly, getter=isTouched) BOOL touched;
@property (copy) void (^valueChangedHandler)(id, float, BOOL);
@property (copy) void (^pressedChangedHandler)(id, float, BOOL);
@property (copy) void (^touchedChangedHandler)(id, float, BOOL, BOOL);
- (void)setValue:(float)value;
@end

@protocol LAxis <LElement>
@property (readonly) float value;
@property (copy) void (^valueChangedHandler)(id, float);
- (void)setValue:(float)value;
@end

@protocol LDpad <LElement>
@property (readonly) id<LAxis> xAxis;
@property (readonly) id<LAxis> yAxis;
@property (readonly) id<LButton> up;
@property (readonly) id<LButton> down;
@property (readonly) id<LButton> left;
@property (readonly) id<LButton> right;
@property (copy) void (^valueChangedHandler)(id, float, float);
- (void)setValueForXAxis:(float)x yAxis:(float)y;
@end

@protocol LTouchpad <NSObject>
@property (readonly) id button;
@property (readonly) id touchSurface;
@property (readonly) NSInteger touchState;
@property (nonatomic) BOOL reportsAbsoluteTouchSurfaceValues;
@property (nonatomic, copy, nullable) void (^touchDown)(id, float, float, float, BOOL);
@property (nonatomic, copy, nullable) void (^touchMoved)(id, float, float, float, BOOL);
@property (nonatomic, copy, nullable) void (^touchUp)(id, float, float, float, BOOL);
- (void)setValueForXAxis:(float)xAxis yAxis:(float)yAxis touchDown:(BOOL)touchDown buttonValue:(float)buttonValue;
@end

@protocol LProfile <NSObject>
@property (readonly) id controller;
@property (readonly) id device;
@property (readonly) NSTimeInterval lastEventTimestamp;
@property (readonly) BOOL hasRemappedElements;
@property (readonly) NSDictionary *elements;
@property (readonly) NSDictionary *buttons;
@property (readonly) NSDictionary *axes;
@property (readonly) NSDictionary *dpads;
@property (readonly) NSDictionary *touchpads;
@property (readonly) NSSet *allElements;
@property (readonly) NSSet *allButtons;
@property (readonly) NSSet *allAxes;
@property (readonly) NSSet *allDpads;
@property (readonly) NSSet *allTouchpads;
- (id)objectForKeyedSubscript:(NSString *)key;
- (id)capture;
- (void)setStateFromExtendedGamepad:(id)other;
- (void)setStateFromMicroGamepad:(id)other;
@end

@protocol LController <NSObject>
@property (readonly) id motion;
@property (readonly) NSString *vendorName;
@property (readonly) NSString *productCategory;
@property NSInteger playerIndex;
@property (readonly, getter=isAttachedToDevice) BOOL attachedToDevice;
@property (readonly, getter=isSnapshot) BOOL snapshot;
@property (strong) dispatch_queue_t handlerQueue;
@property (readonly) id<LProfile> extendedGamepad;
@property (readonly) id<LProfile> gamepad;
@property (readonly) id<LProfile> microGamepad;
@property (readonly) id<LProfile> physicalInputProfile;
@property (readonly) id battery;
@property (readonly) id light;
@property (readonly) id haptics;
- (id<LController>)capture;
@end

@protocol LSaves <NSObject>
- (id)saveSnapshot;
@end

@protocol LSnapshot <NSObject>
@property (readonly) NSData *snapshotData;
- (instancetype)initWithSnapshotData:(NSData *)data;
@end

@interface NSObject (LFactory)
+ (id<LController>)controllerWithExtendedGamepad;
+ (id<LController>)controllerWithMicroGamepad;
@end

static NSString *sorted(NSSet *set)
{
    return [[[set allObjects] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
}

static NSString *kind(id element)
{
    if ([element respondsToSelector:@selector(xAxis)])
        return @"dpad";
    if ([element respondsToSelector:@selector(isPressed)])
        return @"button";
    return @"axis";
}

static id attemptOut(id (^block)(void), NSString **what)
{
    @try {
        id value = block();
        *what = value ? @"non-nil" : @"(nil)";
        return value;
    } @catch (NSException *raised) {
        *what = [NSString stringWithFormat:@"raised %@: %@", raised.name, raised.reason];
        return nil;
    }
}

static NSString *attempt(id (^block)(void))
{
    @try {
        id value = block();
        return value ? [NSString stringWithFormat:@"%@", value] : @"(nil)";
    } @catch (NSException *raised) {
        return [NSString stringWithFormat:@"raised %@: %@", raised.name, raised.reason];
    }
}

static id send0(id o, SEL s)
{
    return o ? ((id (*)(id, SEL))objc_msgSend)(o, s) : nil;
}

static NSString *f(float value)
{
    if (value == 0)
        return @"0";
    return [NSString stringWithFormat:@"%.9g", value];
}

static NSString *describeElement(id<LElement> e)
{
    NSString *collection = e.collection ? sorted([e.collection aliases]) : @"-";
    return [NSString stringWithFormat:@"%@ aliases=%@ local=%@ unmappedLocal=%@ sf=%@ unmappedSf=%@ analog=%d system=%d preferred=%ld collection=%@", kind(e), sorted(e.aliases),
            e.localizedName, e.unmappedLocalizedName, e.sfSymbolsName, e.unmappedSfSymbolsName, e.analog, e.boundToSystemGesture, (long)e.preferredSystemGestureState, collection];
}

static NSString *stateOf(id<LProfile> profile)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in [[profile.elements allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        id e = profile.elements[key];
        NSString *k = kind(e);
        if ([k isEqual:@"button"])
            [parts addObject:[NSString stringWithFormat:@"%@=%@/%d/%d", key, f([(id<LButton>)e value]), [(id<LButton>)e isPressed], [(id<LButton>)e isTouched]]];
        else if ([k isEqual:@"axis"])
            [parts addObject:[NSString stringWithFormat:@"%@=%@", key, f([(id<LAxis>)e value])]];
    }
    return [parts componentsJoinedByString:@" "];
}

static void spin(void)
{
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.004, false);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.001, false);
}

static void hook(id<LProfile> profile, NSMutableArray *log)
{
    for (NSString *key in [[profile.elements allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        id e = profile.elements[key];
        NSString *k = kind(e);
        NSString *first = [[[[(id<LElement>)e aliases] allObjects] sortedArrayUsingSelector:@selector(compare:)] firstObject];
        if (![key isEqual:first])
            continue;
        if ([k isEqual:@"button"]) {
            id<LButton> b = e;
            b.valueChangedHandler = ^(id x, float v, BOOL p) { [log addObject:[NSString stringWithFormat:@"%@ vch %@ %d", key, f(v), p]]; };
            b.pressedChangedHandler = ^(id x, float v, BOOL p) { [log addObject:[NSString stringWithFormat:@"%@ pch %@ %d", key, f(v), p]]; };
            b.touchedChangedHandler = ^(id x, float v, BOOL p, BOOL t) { [log addObject:[NSString stringWithFormat:@"%@ tch %@ %d %d", key, f(v), p, t]]; };
        } else if ([k isEqual:@"axis"]) {
            id<LAxis> a = e;
            a.valueChangedHandler = ^(id x, float v) { [log addObject:[NSString stringWithFormat:@"%@ vch %@", key, f(v)]]; };
        } else {
            id<LDpad> d = e;
            d.valueChangedHandler = ^(id x, float xv, float yv) { [log addObject:[NSString stringWithFormat:@"%@ vch %@ %@", key, f(xv), f(yv)]]; };
        }
    }
}

@protocol LMotion <NSObject>
@property (readonly) id controller;
@property (copy) void (^valueChangedHandler)(id);
@property (readonly) BOOL sensorsRequireManualActivation;
@property BOOL sensorsActive;
@property (readonly) BOOL hasGravityAndUserAcceleration;
@property (readonly) BOOL hasAttitude;
@property (readonly) BOOL hasRotationRate;
@property (readonly) BOOL hasAttitudeAndRotationRate;
- (void)setStateFromMotion:(id)motion;
@end

static NSArray *drive(Class controllerClass, BOOL micro)
{
    NSMutableArray *log = [NSMutableArray array];
    id<LController> controller = micro ? [controllerClass controllerWithMicroGamepad] : [controllerClass controllerWithExtendedGamepad];
    id<LProfile> profile = micro ? controller.microGamepad : controller.extendedGamepad;
    [log addObject:[NSString stringWithFormat:@"controller vendor=%@ product=%@ player=%ld attached=%d snapshot=%d queueMain=%d", controller.vendorName, controller.productCategory,
                    (long)controller.playerIndex, controller.attachedToDevice, controller.snapshot, controller.handlerQueue == dispatch_get_main_queue()]];
    [log addObject:[NSString stringWithFormat:@"identity ext=%d gamepad=%d micro=%d physical=%d battery=%d light=%d haptics=%d", controller.extendedGamepad != nil,
                    controller.gamepad == controller.extendedGamepad && controller.gamepad != nil, controller.microGamepad == profile, controller.physicalInputProfile == profile,
                    controller.battery != nil, controller.light != nil, controller.haptics != nil]];
    [log addObject:[NSString stringWithFormat:@"profile controller=%d device=%d timestamp=%g remapped=%d", profile.controller == controller, profile.device == controller,
                    profile.lastEventTimestamp, profile.hasRemappedElements]];
    NSArray *keys = [[profile.elements allKeys] sortedArrayUsingSelector:@selector(compare:)];
    [log addObject:[NSString stringWithFormat:@"counts elements=%lu buttons=%lu axes=%lu dpads=%lu touchpads=%lu all=%lu allButtons=%lu allAxes=%lu allDpads=%lu allTouchpads=%lu",
                    (unsigned long)profile.elements.count, (unsigned long)profile.buttons.count, (unsigned long)profile.axes.count, (unsigned long)profile.dpads.count,
                    (unsigned long)profile.touchpads.count, (unsigned long)profile.allElements.count, (unsigned long)profile.allButtons.count, (unsigned long)profile.allAxes.count,
                    (unsigned long)profile.allDpads.count, (unsigned long)profile.allTouchpads.count]];
    for (NSString *key in keys)
        [log addObject:[NSString stringWithFormat:@"element %@: %@", key, describeElement(profile.elements[key])]];
    for (NSString *key in keys)
        [log addObject:[NSString stringWithFormat:@"subscript %@ same=%d", key, profile[key] == profile.elements[key]]];
    NSArray *names = micro ? @[@"dpad", @"buttonA", @"buttonX", @"buttonMenu"]
                           : @[@"dpad", @"buttonA", @"buttonB", @"buttonX", @"buttonY", @"buttonMenu", @"buttonOptions", @"buttonHome", @"leftThumbstick", @"rightThumbstick", @"leftShoulder",
                               @"rightShoulder", @"leftTrigger", @"rightTrigger", @"leftThumbstickButton", @"rightThumbstickButton"];
    for (NSString *name in names)
        [log addObject:[NSString stringWithFormat:@"property %@ -> %@", name, sorted([(id<LElement>)[(NSObject *)profile valueForKey:name] aliases])]];
    id<LDpad> dpad = [(NSObject *)profile valueForKey:@"dpad"];
    [log addObject:[NSString stringWithFormat:@"dpad parts x=%@ y=%@ up=%@ down=%@ left=%@ right=%@", sorted(dpad.xAxis.aliases), sorted(dpad.yAxis.aliases), sorted(dpad.up.aliases),
                    sorted(dpad.down.aliases), sorted(dpad.left.aliases), sorted(dpad.right.aliases)]];
    hook(profile, log);

    NSMutableArray *buttons = [NSMutableArray array], *axes = [NSMutableArray array], *dpads = [NSMutableArray array];
    for (NSString *key in keys) {
        id e = profile.elements[key];
        NSString *first = [[[[(id<LElement>)e aliases] allObjects] sortedArrayUsingSelector:@selector(compare:)] firstObject];
        if (![key isEqual:first])
            continue;
        NSString *k = kind(e);
        [([k isEqual:@"button"] ? buttons : [k isEqual:@"axis"] ? axes : dpads) addObject:key];
    }
    static const float values[] = {0, 1, 0.5, 0.2, 0.01, 1e-6, -0.5, -1, 1.5, -1.5, 0.7, 0.3, 0.49, 0.51, 2, -0.2, 1e-9, 3e-8, 2.9e-8, 0.001953125f, 0.002f, 0.0019531251f, -0.0f, 1.0000001f};
    srandom(20260921);
    for (int step = 0; step < 4000; step++) {
        int which = random() % 3;
        float a = values[random() % 24], b = values[random() % 24];
        NSString *op;
        if (which == 0) {
            NSString *key = buttons[random() % buttons.count];
            [(id<LButton>)profile.elements[key] setValue:a];
            op = [NSString stringWithFormat:@"button %@ setValue %@", key, f(a)];
        } else if (which == 1) {
            NSString *key = axes[random() % axes.count];
            [(id<LAxis>)profile.elements[key] setValue:a];
            op = [NSString stringWithFormat:@"axis %@ setValue %@", key, f(a)];
        } else {
            NSString *key = dpads[random() % dpads.count];
            [(id<LDpad>)profile.elements[key] setValueForXAxis:a yAxis:b];
            op = [NSString stringWithFormat:@"dpad %@ set %@ %@", key, f(a), f(b)];
        }
        NSUInteger before = log.count;
        spin();
        NSMutableArray *events = [NSMutableArray array];
        for (NSUInteger i = before; i < log.count; i++)
            [events addObject:log[i]];
        [log removeObjectsInRange:NSMakeRange(before, log.count - before)];
        [log addObject:[NSString stringWithFormat:@"%@ => %@", op, [events componentsJoinedByString:@"; "]]];
        if (step % 25 == 0)
            [log addObject:[NSString stringWithFormat:@"state %@", stateOf(profile)]];
    }
    id<LProfile> captured = [profile capture];
    [log addObject:[NSString stringWithFormat:@"capture same-class=%d controller=%d state-equal=%d", [captured isMemberOfClass:[(NSObject *)profile class]], captured.controller == nil,
                    [stateOf(captured) isEqual:stateOf(profile)]]];
    id<LController> other = micro ? [controllerClass controllerWithMicroGamepad] : [controllerClass controllerWithExtendedGamepad];
    NSMutableArray *copyLog = [NSMutableArray array];
    id<LProfile> target = micro ? other.microGamepad : other.extendedGamepad;
    hook(target, copyLog);
    if (micro)
        [target setStateFromMicroGamepad:profile];
    else
        [target setStateFromExtendedGamepad:profile];
    spin();
    [log addObject:[NSString stringWithFormat:@"setState events: %@", [copyLog componentsJoinedByString:@"; "]]];
    [log addObject:[NSString stringWithFormat:@"setState state-equal=%d", [stateOf(target) isEqual:stateOf(profile)]]];
    id<LController> capturedController = [controller capture];
    [log addObject:[NSString stringWithFormat:@"controller capture vendor=%@ product=%@ snapshot=%d ext=%d", capturedController.vendorName, capturedController.productCategory,
                    capturedController.snapshot, capturedController.extendedGamepad != nil]];
    controller.playerIndex = 2;

    {
        id<LController> mc = micro ? [controllerClass controllerWithMicroGamepad] : [controllerClass controllerWithExtendedGamepad];
        id m = mc.motion;
        NSMutableArray *fired = [NSMutableArray array];
        [(id<LMotion>)m setValueChangedHandler:^(id x) { [fired addObject:@"changed"]; }];
        typedef struct { double x, y, z; } V3;
        typedef struct { double x, y, z, w; } V4;
        NSString *(^dump)(id) = ^NSString *(id object) {
            V3 (*vec)(id, SEL) = (V3 (*)(id, SEL))objc_msgSend;
            V4 (*quat)(id, SEL) = (V4 (*)(id, SEL))objc_msgSend;
            V3 g = vec(object, @selector(gravity)), u = vec(object, @selector(userAcceleration)), a = vec(object, @selector(acceleration)), r = vec(object, @selector(rotationRate));
            V4 q = quat(object, @selector(attitude));
            id<LMotion> lm = object;
            return [NSString stringWithFormat:@"req=%d active=%d hasGU=%d hasAtt=%d hasRot=%d hasAR=%d g=(%g %g %g) u=(%g %g %g) a=(%g %g %g) att=(%g %g %g %g) rot=(%g %g %g) controller=%d", lm.sensorsRequireManualActivation,
                    lm.sensorsActive, lm.hasGravityAndUserAcceleration, lm.hasAttitude, lm.hasRotationRate, lm.hasAttitudeAndRotationRate, g.x, g.y, g.z, u.x, u.y, u.z, a.x, a.y, a.z, q.x, q.y, q.z, q.w, r.x, r.y, r.z, lm.controller == mc];
        };
        [log addObject:[NSString stringWithFormat:@"motion initial %@", dump(m)]];
        void (^setVec)(SEL, V3) = ^(SEL selector, V3 v) { ((void (*)(id, SEL, V3))objc_msgSend)(m, selector, v); };
        setVec(@selector(setGravity:), (V3){0, -1, 0});
        setVec(@selector(setUserAcceleration:), (V3){0.1, 0.2, 0.3});
        setVec(@selector(setAcceleration:), (V3){1, 2, 3});
        setVec(@selector(setRotationRate:), (V3){4, 5, 6});
        ((void (*)(id, SEL, V4))objc_msgSend)(m, @selector(setAttitude:), (V4){0.1, 0.2, 0.3, 0.9});
        [(id<LMotion>)m setSensorsActive:NO];
        spin();
        [log addObject:[NSString stringWithFormat:@"motion after setters %@ fired=%lu", dump(m), (unsigned long)fired.count]];
        id<LController> other = micro ? [controllerClass controllerWithMicroGamepad] : [controllerClass controllerWithExtendedGamepad];
        NSMutableArray *copyFired = [NSMutableArray array];
        [(id<LMotion>)other.motion setValueChangedHandler:^(id x) { [copyFired addObject:@"changed"]; }];
        [(id<LMotion>)other.motion setStateFromMotion:m];
        [(id<LMotion>)other.motion setStateFromMotion:m];
        spin();
        [log addObject:[NSString stringWithFormat:@"motion copied %@ fired=%lu", dump(other.motion), (unsigned long)copyFired.count]];
        id<LController> cap = [mc capture];
        [log addObject:[NSString stringWithFormat:@"motion captured %@", dump(cap.motion)]];
    }

    [log addObject:[NSString stringWithFormat:@"player after set %ld", (long)controller.playerIndex]];

    {
        id<LController> extra = micro ? [controllerClass controllerWithMicroGamepad] : [controllerClass controllerWithExtendedGamepad];
        id<LProfile> p = micro ? extra.microGamepad : extra.extendedGamepad;
        id<LButton> a = [(NSObject *)p valueForKey:@"buttonA"];
        NSMutableArray *events = [NSMutableArray array];
        a.valueChangedHandler = ^(id x, float v, BOOL pr) { [events addObject:[NSString stringWithFormat:@"first %g", v]]; };
        [a setValue:0.5];
        a.valueChangedHandler = ^(id x, float v, BOOL pr) { [events addObject:[NSString stringWithFormat:@"second %g", v]]; };
        spin();
        [log addObject:[NSString stringWithFormat:@"handler replaced before delivery: %@", [events componentsJoinedByString:@","]]];
        [events removeAllObjects];
        [a setValue:0.7];
        a.valueChangedHandler = nil;
        spin();
        [log addObject:[NSString stringWithFormat:@"handler removed before delivery: %@", [events componentsJoinedByString:@","]]];
        dispatch_queue_t queue = dispatch_queue_create("custom-label", DISPATCH_QUEUE_SERIAL);
        extra.handlerQueue = queue;
        [events removeAllObjects];
        a.valueChangedHandler = ^(id x, float v, BOOL pr) { [events addObject:[NSString stringWithFormat:@"%g on %s main=%d", v, dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), [NSThread isMainThread]]]; };
        [a setValue:0.1];
        [a setValue:0.2];
        [a setValue:0.3];
        dispatch_sync(queue, ^{});
        [log addObject:[NSString stringWithFormat:@"custom queue: %@ queueKept=%d", [events componentsJoinedByString:@","], extra.handlerQueue == queue]];
        id<LElement> element = [(NSObject *)p valueForKey:@"buttonA"];
        [(NSObject *)element setValue:@"Custom" forKey:@"localizedName"];
        [(NSObject *)element setValue:@"custom.symbol" forKey:@"sfSymbolsName"];
        [(NSObject *)element setValue:@"Unmapped" forKey:@"unmappedLocalizedName"];
        [(NSObject *)element setValue:@"unmapped.symbol" forKey:@"unmappedSfSymbolsName"];
        [(NSObject *)element setValue:@2 forKey:@"preferredSystemGestureState"];
        [log addObject:[NSString stringWithFormat:@"element setters: %@ %@ %@ %@ %ld", element.localizedName, element.sfSymbolsName, element.unmappedLocalizedName, element.unmappedSfSymbolsName, (long)element.preferredSystemGestureState]];
        __weak id weakProfile;
        @autoreleasepool {
            id<LController> temp = micro ? [controllerClass controllerWithMicroGamepad] : [controllerClass controllerWithExtendedGamepad];
            id<LProfile> tp = micro ? temp.microGamepad : temp.extendedGamepad;
            weakProfile = tp;
            [log addObject:[NSString stringWithFormat:@"temp controller kept profile=%d", [tp controller] != nil]];
        }
                id direct = [[NSClassFromString(micro ? (controllerClass == NSClassFromString(@"GCController") ? @"GCMicroGamepad" : @"RevenantHostGCMicroGamepad") : (controllerClass == NSClassFromString(@"GCController") ? @"GCExtendedGamepad" : @"RevenantHostGCExtendedGamepad")) alloc] init];
        id<LProfile> dp = direct;
        [log addObject:[NSString stringWithFormat:@"direct init: profile=%d elements=%lu controller=%d device=%d", dp != nil, (unsigned long)dp.elements.count, dp.controller != nil, dp.device != nil]];
    }
    return log;
}



#import <GameController/GameController.h>

@protocol LController <NSObject>
@property (nonatomic, copy, readonly, nullable) id battery;
@property (nonatomic, retain, readonly, nullable) id light;
@property (nonatomic, retain, readonly, nullable) id haptics;
@end

@protocol LKProfile <NSObject>
@property (readonly) NSDictionary *elements;
@property (readonly) NSDictionary *buttons;
@property (readonly, getter=isAnyKeyPressed) BOOL anyKeyPressed;
@property (nonatomic, copy, nullable) void (^keyChangedHandler)(id, id, GCKeyCode, BOOL);
- (GCDeviceButtonInput *)buttonForKeyCode:(GCKeyCode)code;
@end


extern BOOL revenantHost_GCGamepadSnapShotDataV100FromNSData(GCGamepadSnapShotDataV100 *, NSData *);
extern NSData *revenantHost_NSDataFromGCGamepadSnapShotDataV100(GCGamepadSnapShotDataV100 *);
extern BOOL revenantHost_GCExtendedGamepadSnapShotDataV100FromNSData(GCExtendedGamepadSnapShotDataV100 *, NSData *);
extern NSData *revenantHost_NSDataFromGCExtendedGamepadSnapShotDataV100(GCExtendedGamepadSnapShotDataV100 *);
extern BOOL revenantHost_GCExtendedGamepadSnapshotDataFromNSData(GCExtendedGamepadSnapshotData *, NSData *);
extern NSData *revenantHost_NSDataFromGCExtendedGamepadSnapshotData(GCExtendedGamepadSnapshotData *);
extern BOOL revenantHost_GCMicroGamepadSnapShotDataV100FromNSData(GCMicroGamepadSnapShotDataV100 *, NSData *);
extern NSData *revenantHost_NSDataFromGCMicroGamepadSnapShotDataV100(GCMicroGamepadSnapShotDataV100 *);
extern BOOL revenantHost_GCMicroGamepadSnapshotDataFromNSData(GCMicroGamepadSnapshotData *, NSData *);
extern NSData *revenantHost_NSDataFromGCMicroGamepadSnapshotData(GCMicroGamepadSnapshotData *);
extern const long revenantHost_GCCurrentExtendedGamepadSnapshotDataVersion;
extern const long revenantHost_GCCurrentMicroGamepadSnapshotDataVersion;

static NSData *pattern(unsigned length)
{
    NSMutableData *d = [NSMutableData dataWithLength:length];
    unsigned char *b = d.mutableBytes;
    for (unsigned i = 0; i < length; i++)
        b[i] = (unsigned char)(0x40 + (i % 26));
    return d;
}

static NSString *whole(NSData *d)
{
    if (!d)
        return @"(nil)";
    const unsigned char *b = d.bytes;
    NSMutableString *s = [NSMutableString stringWithFormat:@"%lu:", (unsigned long)d.length];
    for (NSUInteger i = 0; i < d.length; i++)
        [s appendFormat:@"%02x", b[i]];
    return s;
}

static NSArray *snapshotFunctionGroup(BOOL port)
{
    NSMutableArray *log = [NSMutableArray array];
    GCGamepadSnapShotDataV100 g1;
    memset(&g1, 0, sizeof(g1));
    g1.dpadX = 0.25f;
    g1.buttonA = 1.0f;
    g1.buttonY = 0.125f;
    GCGamepadSnapShotDataV100 g2 = g1;
    g2.version = 0x0200;
    g2.size = 999;
    for (int which = 0; which < 2; which++) {
        GCGamepadSnapShotDataV100 *in = which ? &g2 : &g1;
        [log addObject:[NSString stringWithFormat:@"gamepad NSDataFrom(%d) = %@", which,
                                                  whole(port ? revenantHost_NSDataFromGCGamepadSnapShotDataV100(in)
                                                             : NSDataFromGCGamepadSnapShotDataV100(in))]];
        [log addObject:[NSString stringWithFormat:@"gamepad NSDataFrom(NULL) = %@",
                                                  port ? revenantHost_NSDataFromGCGamepadSnapShotDataV100(NULL) : NSDataFromGCGamepadSnapShotDataV100(NULL)]];
    }
    GCExtendedGamepadSnapShotDataV100 e1;
    memset(&e1, 0, sizeof(e1));
    e1.buttonB = 0.5f;
    e1.leftTrigger = 0.75f;
    [log addObject:[NSString stringWithFormat:@"extended NSDataFromV100 = %@",
                                              whole(port ? revenantHost_NSDataFromGCExtendedGamepadSnapShotDataV100(&e1)
                                                         : NSDataFromGCExtendedGamepadSnapShotDataV100(&e1))]];
    GCExtendedGamepadSnapshotData e2;
    memset(&e2, 0, sizeof(e2));
    e2.buttonA = 1.0f;
    e2.leftThumbstickX = 0.5f;
    e2.supportsClickableThumbsticks = 1;
    e2.leftThumbstickButton = 1;
    [log addObject:[NSString stringWithFormat:@"extended NSDataFrom = %@",
                                              whole(port ? revenantHost_NSDataFromGCExtendedGamepadSnapshotData(&e2)
                                                         : NSDataFromGCExtendedGamepadSnapshotData(&e2))]];
    GCExtendedGamepadSnapshotData e3 = e2;
    e3.version = GCExtendedGamepadSnapshotDataVersion1;
    e3.size = sizeof(GCExtendedGamepadSnapShotDataV100);
    [log addObject:[NSString stringWithFormat:@"extended NSDataFrom with the V100 header = %@",
                                              whole(port ? revenantHost_NSDataFromGCExtendedGamepadSnapshotData(&e3)
                                                         : NSDataFromGCExtendedGamepadSnapshotData(&e3))]];
    GCMicroGamepadSnapshotData m1;
    memset(&m1, 0, sizeof(m1));
    m1.dpadX = -1.0f;
    m1.buttonA = 0.5f;
    [log addObject:[NSString stringWithFormat:@"micro NSDataFrom = %@",
                                              whole(port ? revenantHost_NSDataFromGCMicroGamepadSnapshotData(&m1)
                                                         : NSDataFromGCMicroGamepadSnapshotData(&m1))]];
    GCMicroGamepadSnapShotDataV100 m2;
    memset(&m2, 0, sizeof(m2));
    m2.buttonX = 1.0f;
    [log addObject:[NSString stringWithFormat:@"micro NSDataFromV100 = %@",
                                              whole(port ? revenantHost_NSDataFromGCMicroGamepadSnapShotDataV100(&m2)
                                                         : NSDataFromGCMicroGamepadSnapShotDataV100(&m2))]];
    [log addObject:[NSString stringWithFormat:@"versions extended=%ld micro=%ld",
                                              (long)(port ? revenantHost_GCCurrentExtendedGamepadSnapshotDataVersion
                                                          : GCCurrentExtendedGamepadSnapshotDataVersion),
                                              (long)(port ? revenantHost_GCCurrentMicroGamepadSnapshotDataVersion
                                                          : GCCurrentMicroGamepadSnapshotDataVersion)]];

    NSArray *inputs = @[ (id)[NSData data], (id)pattern(4), (id)pattern(20), (id)pattern(35), (id)pattern(36), (id)pattern(37),
                        (id)pattern(59), (id)pattern(60), (id)pattern(61), (id)pattern(63), (id)pattern(64), (id)pattern(200) ];
    for (NSData *in in inputs) {
        GCGamepadSnapShotDataV100 g;
        GCExtendedGamepadSnapShotDataV100 ev;
        GCExtendedGamepadSnapshotData ec;
        GCMicroGamepadSnapShotDataV100 mv;
        GCMicroGamepadSnapshotData mc;
        memset(&g, 0xEE, sizeof(g));
        memset(&ev, 0xEE, sizeof(ev));
        memset(&ec, 0xEE, sizeof(ec));
        memset(&mv, 0xEE, sizeof(mv));
        memset(&mc, 0xEE, sizeof(mc));
        [log addObject:[NSString stringWithFormat:@"read %3lu gamepadV100=%d extendedV100=%d extended=%d microV100=%d micro=%d",
                                              (unsigned long)in.length,
                                              port ? revenantHost_GCGamepadSnapShotDataV100FromNSData(&g, in) : GCGamepadSnapShotDataV100FromNSData(&g, in),
                                              port ? revenantHost_GCExtendedGamepadSnapShotDataV100FromNSData(&ev, in)
                                                   : GCExtendedGamepadSnapShotDataV100FromNSData(&ev, in),
                                              port ? revenantHost_GCExtendedGamepadSnapshotDataFromNSData(&ec, in)
                                                   : GCExtendedGamepadSnapshotDataFromNSData(&ec, in),
                                              port ? revenantHost_GCMicroGamepadSnapShotDataV100FromNSData(&mv, in)
                                                   : GCMicroGamepadSnapShotDataV100FromNSData(&mv, in),
                                              port ? revenantHost_GCMicroGamepadSnapshotDataFromNSData(&mc, in)
                                                   : GCMicroGamepadSnapshotDataFromNSData(&mc, in)]];
        [log addObject:[NSString stringWithFormat:@"read %3lu gamepadV100 struct=0x%04x/%u extended=0x%04x/%u micro=0x%04x/%u",
                                              (unsigned long)in.length, g.version, g.size, ec.version, ec.size, mc.version, mc.size]];
        uint16_t versions[] = {0x0000, 0x0100, 0x0101, 0x0200};
        for (unsigned v = 0; v < 4; v++) {
            for (unsigned len = 0; len <= 66; len += 6) {
                NSMutableData *blob = [NSMutableData dataWithLength:len];
                if (len >= 4) {
                    uint16_t *h = blob.mutableBytes;
                    h[0] = versions[v];
                    h[1] = (uint16_t)len;
                }
                memset(&g, 0xEE, sizeof(g));
                memset(&ec, 0xEE, sizeof(ec));
                memset(&mc, 0xEE, sizeof(mc));
                [log addObject:[NSString stringWithFormat:@"blob 0x%04x %2lu gamepad=%d extended=%d micro=%d", versions[v], (unsigned long)len,
                                                      port ? revenantHost_GCGamepadSnapShotDataV100FromNSData(&g, blob)
                                                           : GCGamepadSnapShotDataV100FromNSData(&g, blob),
                                                      port ? revenantHost_GCExtendedGamepadSnapshotDataFromNSData(&ec, blob)
                                                           : GCExtendedGamepadSnapshotDataFromNSData(&ec, blob),
                                                      port ? revenantHost_GCMicroGamepadSnapshotDataFromNSData(&mc, blob)
                                                           : GCMicroGamepadSnapshotDataFromNSData(&mc, blob)]];
            }
        }
    }
    {
        GCGamepadSnapShotDataV100 g;
        GCExtendedGamepadSnapShotDataV100 ev;
        GCExtendedGamepadSnapshotData ec;
        GCMicroGamepadSnapShotDataV100 mv;
        GCMicroGamepadSnapshotData mc;
        NSData *good = (NSData *)[NSMutableData dataWithLength:36];
        [log addObject:[NSString stringWithFormat:@"nil data gamepad=%d extendedV100=%d extended=%d microV100=%d micro=%d",
                                                  port ? revenantHost_GCGamepadSnapShotDataV100FromNSData(&g, nil)
                                                       : GCGamepadSnapShotDataV100FromNSData(&g, nil),
                                                  port ? revenantHost_GCExtendedGamepadSnapShotDataV100FromNSData(&ev, nil)
                                                       : GCExtendedGamepadSnapShotDataV100FromNSData(&ev, nil),
                                                  port ? revenantHost_GCExtendedGamepadSnapshotDataFromNSData(&ec, nil)
                                                       : GCExtendedGamepadSnapshotDataFromNSData(&ec, nil),
                                                  port ? revenantHost_GCMicroGamepadSnapShotDataV100FromNSData(&mv, nil)
                                                       : GCMicroGamepadSnapShotDataV100FromNSData(&mv, nil),
                                                  port ? revenantHost_GCMicroGamepadSnapshotDataFromNSData(&mc, nil)
                                                       : GCMicroGamepadSnapshotDataFromNSData(&mc, nil)]];
        [log addObject:[NSString stringWithFormat:@"NULL out with data gamepad=%d extendedV100=%d extended=%d microV100=%d micro=%d",
                                                  port ? revenantHost_GCGamepadSnapShotDataV100FromNSData(NULL, good)
                                                       : GCGamepadSnapShotDataV100FromNSData(NULL, good),
                                                  port ? revenantHost_GCExtendedGamepadSnapShotDataV100FromNSData(NULL, good)
                                                       : GCExtendedGamepadSnapShotDataV100FromNSData(NULL, good),
                                                  port ? revenantHost_GCExtendedGamepadSnapshotDataFromNSData(NULL, good)
                                                       : GCExtendedGamepadSnapshotDataFromNSData(NULL, good),
                                                  port ? revenantHost_GCMicroGamepadSnapShotDataV100FromNSData(NULL, good)
                                                       : GCMicroGamepadSnapShotDataV100FromNSData(NULL, good),
                                                  port ? revenantHost_GCMicroGamepadSnapshotDataFromNSData(NULL, good)
                                                       : GCMicroGamepadSnapshotDataFromNSData(NULL, good)]];
    }
    return log;
}

static NSString *describeReading(id element)
{
    if (!element)
        return @"(nil)";
    NSString *k = kind(element);
    if ([k isEqual:@"dpad"] || [k isEqual:@"cursor"]) {
        id<LDpad> d = element;
        return [NSString stringWithFormat:@"dpad %@/%@ %@ %@ %@ %@ %@", f(((id<LAxis>)d.xAxis).value), f(((id<LAxis>)d.yAxis).value),
                f(((id<LButton>)d.up).value), f(((id<LButton>)d.down).value), f(((id<LButton>)d.left).value), f(((id<LButton>)d.right).value),
                f(((id<LButton>)d.up).isPressed), f(((id<LButton>)d.left).isPressed)];
    }
    if ([k isEqual:@"axis"])
        return [NSString stringWithFormat:@"axis %f", ((id<LAxis>)element).value];
    if ([k isEqual:@"button"]) {
        id<LButton> b = element;
        return [NSString stringWithFormat:@"button v=%f pressed=%d touched=%d", b.value, b.isPressed, b.isTouched];
    }
    return describeElement(element);
}

static NSArray *touchpadState(BOOL port)
{
    NSMutableArray *log = [NSMutableArray array];
    Class c = port ? NSClassFromString(@"RevenantHostGCControllerTouchpad") : NSClassFromString(@"GCControllerTouchpad");
    id<LTouchpad> touchpad = (id<LTouchpad>)[[c alloc] init];
    [log addObject:[NSString stringWithFormat:@"touchpad init=%d", touchpad != nil]];
    [log addObject:[NSString stringWithFormat:@"touchpad state=%ld absolute=%d", (long)touchpad.touchState, touchpad.reportsAbsoluteTouchSurfaceValues]];
    [log addObject:[NSString stringWithFormat:@"touchpad handlers before=%d/%d/%d", touchpad.touchDown != nil, touchpad.touchMoved != nil, touchpad.touchUp != nil]];

    NSArray *moves = @[@[@0.5f, @(-0.25f), @YES, @0.75f], @[@0.75f, @(-0.5f), @YES, @1.0f], @[@0, @0, @NO, @0]];
    for (NSArray *move in moves) {
        [touchpad setValueForXAxis:[move[0] floatValue] yAxis:[move[1] floatValue]
                          touchDown:[move[2] boolValue] buttonValue:[move[3] floatValue]];
        [log addObject:[NSString stringWithFormat:@"touchpad after x=%f y=%f down=%d: state=%ld",
                      [move[0] floatValue], [move[1] floatValue], [move[2] boolValue], (long)touchpad.touchState]];
    }

    touchpad.reportsAbsoluteTouchSurfaceValues = touchpad.reportsAbsoluteTouchSurfaceValues;
    [log addObject:[NSString stringWithFormat:@"touchpad absolute after set=%d", touchpad.reportsAbsoluteTouchSurfaceValues]];
    return log;
}

static NSArray *touchpadElements(void)
{
    NSMutableArray *log = [NSMutableArray array];
    id<LTouchpad> t = (id<LTouchpad>)[[NSClassFromString(@"RevenantHostGCControllerTouchpad") alloc] init];
    id button = t.button, surface = t.touchSurface;
    [log addObject:[NSString stringWithFormat:@"port touchpad children: button=%s surface=%s", describeElement(button).UTF8String, describeElement(surface).UTF8String]];
    if (!button || !surface)
        return log;

    [t setValueForXAxis:0.5f yAxis:-0.25f touchDown:YES buttonValue:0.75f];
    id<LDpad> s = surface;
    [log addObject:[NSString stringWithFormat:@"port touchpad down: surface=%@ button=%@", describeReading(s), describeReading(button)]];
    [t setValueForXAxis:0.75f yAxis:-0.5f touchDown:YES buttonValue:1.0f];
    [log addObject:[NSString stringWithFormat:@"port touchpad moving: surface=%@ button=%@", describeReading(s), describeReading(button)]];
    [t setValueForXAxis:5.0f yAxis:-5.0f touchDown:YES buttonValue:2.0f];
    [log addObject:[NSString stringWithFormat:@"port touchpad clamped: surface=%@ button=%@", describeReading(s), describeReading(button)]];
    [t setValueForXAxis:0 yAxis:0 touchDown:NO buttonValue:0];
    [log addObject:[NSString stringWithFormat:@"port touchpad up: surface=%@ button=%@", describeReading(s), describeReading(button)]];
    return log;
}

static NSArray *keyboardGroup(BOOL port)
{
    NSMutableArray *log = [NSMutableArray array];
    Class c = port ? NSClassFromString(@"RevenantHostGCKeyboardInput") : NSClassFromString(@"GCKeyboardInput");
    id<LKProfile> k = (id<LKProfile>)[[c alloc] init];
    [log addObject:[NSString stringWithFormat:@"keyboard init=%d", k != nil]];
    [log addObject:[NSString stringWithFormat:@"keyboard elements=%lu buttons=%lu", (unsigned long)k.elements.count, (unsigned long)k.buttons.count]];
    [log addObject:[NSString stringWithFormat:@"keyboard anyKeyPressed=%d handler=%d", k.isAnyKeyPressed != 0, k.keyChangedHandler != nil]];
    return log;
}

static NSArray *keyboardKeys(NSString *mine, NSString *theirs)
{
    NSMutableArray *log = [NSMutableArray array];
    id<LKProfile> from = (id<LKProfile>)[[NSClassFromString(mine) alloc] init];
    NSMutableDictionary *carried = [NSMutableDictionary dictionary];
    for (NSString *key in from.elements)
        carried[key] = from.elements[key];
    unsigned named = 0, unnamed = 0;
    for (NSString *key in carried.allKeys) {
        if (key.length)
            named++;
        else
            unnamed++;
    }
    id<LKProfile> other = (id<LKProfile>)[[NSClassFromString(theirs) alloc] init];
    unsigned shared = 0, onlyHere = 0, onlyThere = 0;
    for (NSString *key in carried.allKeys) {
        if (!key.length)
            continue;
        if (other.elements[key])
            shared++;
        else
            onlyHere++;
    }
    for (NSString *key in other.elements)
        if (key.length && !carried[key])
            onlyThere++;
    printf("keyboard on this side: %lu keys, %u named, %u unnamed; %u shared, %u only here, %u only there\n",
           (unsigned long)carried.count, named, unnamed, shared, onlyHere, onlyThere);
    [log addObject:[NSString stringWithFormat:@"keyboard shared=%u onlyHere=%u onlyThere=%u",
                  shared > 0 ? 1u : 0u, onlyHere > 0 ? 1u : 0u, onlyThere > 0 ? 1u : 0u]];
    for (NSString *key in [carried.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if (!key.length || !other.elements[key])
            continue;
        [log addObject:[NSString stringWithFormat:@"keyboard key %@ -> %@", key, describeReading(other.elements[key])]];
    }
    return log;
}

static NSArray *keyCodeGroup(BOOL port)
{
    NSMutableArray *log = [NSMutableArray array];
    id<LKProfile> k = (id<LKProfile>)[[NSClassFromString(port ? @"RevenantHostGCKeyboardInput" : @"GCKeyboardInput") alloc] init];
    for (NSNumber *code in @[@(21), @(0), @(9999)])
        [log addObject:[NSString stringWithFormat:@"keyboard code %@ -> %@", code,
                  [k buttonForKeyCode:(GCKeyCode)code.intValue] ? @"a key" : @"nil"]];
    return log;
}

static NSArray *hardwareGroup(BOOL port)
{
    NSMutableArray *log = [NSMutableArray array];
    id<LController> c = (id<LController>)[NSClassFromString(port ? @"RevenantHostGCController" : @"GCController") controllerWithExtendedGamepad];
    [log addObject:[NSString stringWithFormat:@"hardware controller=%d", c != nil]];
    [log addObject:[NSString stringWithFormat:@"hardware battery=%@", c.battery ? @"made" : @"nil"]];
    [log addObject:[NSString stringWithFormat:@"hardware light=%@", c.light ? @"made" : @"nil"]];
    [log addObject:[NSString stringWithFormat:@"hardware haptics=%@", c.haptics ? @"made" : @"nil"]];
    [log addObject:[NSString stringWithFormat:@"hardware coalescedKeyboard=%@",
                  [NSClassFromString(port ? @"RevenantHostGCKeyboard" : @"GCKeyboard") coalescedKeyboard] ? @"made" : @"nil"]];
    return log;
}

@protocol LGamepadExtra <NSObject>
@property (readonly, nullable) id touchpadButton;
@property (readonly, nullable) id touchpadPrimary;
@property (readonly, nullable) id touchpadSecondary;
@end

@protocol LPaddles <NSObject>
@property (readonly, nullable) id paddleButton1;
@property (readonly, nullable) id paddleButton2;
@property (readonly, nullable) id paddleButton3;
@property (readonly, nullable) id paddleButton4;
@end

@protocol LTrigger <LButton>
@property (readonly) NSInteger mode;
@property (readonly) NSInteger status;
@property (readonly) float armPosition;
- (void)setModeOff;
- (void)setModeFeedbackWithStartPosition:(float)startPosition resistiveStrength:(float)resistiveStrength;
- (void)setModeWeaponWithStartPosition:(float)startPosition endPosition:(float)endPosition resistiveStrength:(float)resistiveStrength;
- (void)setModeVibrationWithStartPosition:(float)startPosition amplitude:(float)amplitude frequency:(float)frequency;
- (void)setModeSlopeFeedbackWithStartPosition:(float)startPosition
                                 endPosition:(float)endPosition
                                startStrength:(float)startStrength
                                  endStrength:(float)endStrength;
- (void)setModeFeedbackWithResistiveStrengths:(GCDualSenseAdaptiveTriggerPositionalResistiveStrengths)strengths;
- (void)setModeVibrationWithAmplitudes:(GCDualSenseAdaptiveTriggerPositionalAmplitudes)amplitudes
                             frequency:(float)frequency;
@end

@protocol LDualSenseGamepad <LGamepadExtra>
@property (readonly, nullable) id leftTrigger;
@property (readonly, nullable) id rightTrigger;
@end

static NSArray *paddlesGroup(BOOL host)
{
    NSMutableArray *log = [NSMutableArray array];
    id<LPaddles> x = (id<LPaddles>)[[NSClassFromString(host ? @"GCXboxGamepad" : @"RevenantHostGCXboxGamepad") alloc] init];
    [log addObject:[NSString stringWithFormat:@"paddles %@ %@ %@ %@", x.paddleButton1 ? @"a button" : @"nil",
                  x.paddleButton2 ? @"a button" : @"nil", x.paddleButton3 ? @"a button" : @"nil",
                  x.paddleButton4 ? @"a button" : @"nil"]];
    return log;
}

static NSArray *touchpadsGroup(BOOL host)
{
    NSMutableArray *log = [NSMutableArray array];
    for (NSString *name in @[@"GCDualShockGamepad", @"GCDualSenseGamepad"]) {
        id<LGamepadExtra> g = (id<LGamepadExtra>)[[NSClassFromString(host ? name : [@"RevenantHost" stringByAppendingString:name]) alloc] init];
        [log addObject:[NSString stringWithFormat:@"%@ init=%d", name, g != nil]];
        [log addObject:[NSString stringWithFormat:@"%@ touchpadButton=%@", name, describeReading(g.touchpadButton)]];
        [log addObject:[NSString stringWithFormat:@"%@ touchpadPrimary=%@", name, describeReading(g.touchpadPrimary)]];
        [log addObject:[NSString stringWithFormat:@"%@ touchpadSecondary=%@", name, describeReading(g.touchpadSecondary)]];
        [(id) g.touchpadButton setValue:0.6f];
        [(id<LDpad>)g.touchpadPrimary setValueForXAxis:0.5f yAxis:-0.25f];
        [(id<LDpad>)g.touchpadSecondary setValueForXAxis:-1.0f yAxis:1.0f];
        [log addObject:[NSString stringWithFormat:@"%@ after values: button=%@ primary=%@ secondary=%@", name,
                      describeReading(g.touchpadButton), describeReading(g.touchpadPrimary), describeReading(g.touchpadSecondary)]];
    }
    return log;
}

static NSArray *triggerGroup(BOOL host)
{
    NSMutableArray *log = [NSMutableArray array];
    id<LTrigger> t = (id<LTrigger>)[[NSClassFromString(host ? @"GCDualSenseAdaptiveTrigger" : @"RevenantHostGCDualSenseAdaptiveTrigger") alloc] init];
    BOOL answersButton = [t respondsToSelector:@selector(setValue:)] && [t respondsToSelector:@selector(isPressed)];
    [log addObject:[NSString stringWithFormat:@"trigger init=%d answersButton=%d", (int)(t != nil), (int)answersButton]];
    [log addObject:[NSString stringWithFormat:@"trigger at rest: mode=%ld status=%ld armPosition=%f", (long)t.mode, (long)t.status, t.armPosition]];
    [t setModeOff];
    [log addObject:[NSString stringWithFormat:@"trigger after setModeOff: mode=%ld status=%ld", (long)t.mode, (long)t.status]];
    [t setModeFeedbackWithStartPosition:0.2f resistiveStrength:0.8f];
    [log addObject:[NSString stringWithFormat:@"trigger after setModeFeedback: mode=%ld status=%ld", (long)t.mode, (long)t.status]];
    [t setModeWeaponWithStartPosition:0.1f endPosition:0.9f resistiveStrength:0.7f];
    [log addObject:[NSString stringWithFormat:@"trigger after setModeWeapon: mode=%ld status=%ld", (long)t.mode, (long)t.status]];
    [t setModeVibrationWithStartPosition:0.2f amplitude:0.8f frequency:0.5f];
    [log addObject:[NSString stringWithFormat:@"trigger after setModeVibration: mode=%ld status=%ld", (long)t.mode, (long)t.status]];
    GCDualSenseAdaptiveTriggerPositionalResistiveStrengths strengths = {0.1f, 0.4f, 0.9f, 0.2f, 0.7f};
    GCDualSenseAdaptiveTriggerPositionalAmplitudes amplitudes = {0.1f, 0.4f, 0.9f, 0.2f, 0.7f};
    SEL slope = @selector(setModeSlopeFeedbackWithStartPosition:endPosition:startStrength:endStrength:);
    SEL positionalFeedback = @selector(setModeFeedbackWithResistiveStrengths:);
    SEL positionalVibration = @selector(setModeVibrationWithAmplitudes:frequency:);
    [log addObject:[NSString stringWithFormat:@"trigger carries the 15.4 three: slope=%d strengths=%d amplitudes=%d",
                     (int)[t respondsToSelector:slope], (int)[t respondsToSelector:positionalFeedback],
                     (int)[t respondsToSelector:positionalVibration]]];
    [t setModeSlopeFeedbackWithStartPosition:0.1f endPosition:0.9f startStrength:0.2f endStrength:0.7f];
    [log addObject:[NSString stringWithFormat:@"trigger after setModeSlopeFeedback: mode=%ld status=%ld armPosition=%f",
                     (long)t.mode, (long)t.status, t.armPosition]];
    [t setModeFeedbackWithResistiveStrengths:strengths];
    [log addObject:[NSString stringWithFormat:@"trigger after setModeFeedback(strengths): mode=%ld status=%ld armPosition=%f",
                     (long)t.mode, (long)t.status, t.armPosition]];
    [t setModeVibrationWithAmplitudes:amplitudes frequency:0.5f];
    [log addObject:[NSString stringWithFormat:@"trigger after setModeVibration(amplitudes): mode=%ld status=%ld armPosition=%f",
                     (long)t.mode, (long)t.status, t.armPosition]];
    t.value = 0.6f;
    [log addObject:[NSString stringWithFormat:@"trigger as a button: %@ armPosition=%f", describeReading(t), t.armPosition]];
    return log;
}

static NSArray *gamepadInfo(NSString *name)
{
    NSMutableArray *log = [NSMutableArray array];
    id<LProfile> g = [[NSClassFromString(name) alloc] init];
    [log addObject:[NSString stringWithFormat:@"GCGamepad init=%d elements=%lu controller=%d device=%d", g != nil, (unsigned long)g.elements.count, g.controller != nil, g.device != nil]];
    for (NSString *key in [[g.elements allKeys] sortedArrayUsingSelector:@selector(compare:)])
        [log addObject:[NSString stringWithFormat:@"gamepad element %@: %@", key, describeElement(g.elements[key])]];
    for (NSString *property in @[@"dpad", @"buttonA", @"buttonX", @"leftShoulder", @"rightShoulder", @"buttonY", @"buttonB"])
        if ([(NSObject *)g respondsToSelector:NSSelectorFromString(property)] && !([name containsString:@"Micro"] && ![@[@"dpad", @"buttonA", @"buttonX"] containsObject:property]))
            [log addObject:[NSString stringWithFormat:@"gamepad property %@ -> %@", property, sorted([(id<LElement>)[(NSObject *)g valueForKey:property] aliases])]];
    return log;
}

static void writeValues(id<LProfile> gamepad, NSDictionary *values)
{
    for (NSString *name in values) {
        id element = gamepad.elements[name];
        if (element == nil)
            continue;
        if ([element respondsToSelector:@selector(setValueForXAxis:yAxis:)])
            [(id<LDpad>)element setValueForXAxis:[values[name][0] floatValue] yAxis:[values[name][1] floatValue]];
        else
            [(id<LButton>)element setValue:[values[name][0] floatValue]];
    }
}

static NSString *elementWant(NSArray *values)
{
    NSMutableArray *out = [NSMutableArray array];
    for (NSNumber *value in values)
        [out addObject:[NSString stringWithFormat:@"%f", [value floatValue]]];
    return [out componentsJoinedByString:@","];
}

static NSString *elementReading(id element)
{
    if (element == nil)
        return @"(no element)";
    if ([kind(element) isEqual:@"dpad"]) {
        id<LDpad> d = element;
        return [NSString stringWithFormat:@"%f,%f", ((id<LAxis>)d.xAxis).value, ((id<LAxis>)d.yAxis).value];
    }
    return [NSString stringWithFormat:@"%f", ((id<LAxis>)element).value];
}

static id saveSnapshotOf(id gamepad, NSString **what)
{
    if (![gamepad respondsToSelector:@selector(saveSnapshot)]) {
        *what = @"no saveSnapshot";
        return nil;
    }
    return attemptOut(^id { return [(id<LSaves>)gamepad saveSnapshot]; }, what);
}

static NSString *hexData(NSData *data)
{
    if (data == nil)
        return @"(nil)";
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSMutableString *out = [NSMutableString stringWithFormat:@"%lu:", (unsigned long)[data length]];
    for (NSUInteger i = 0; i < [data length]; i++)
        [out appendFormat:@" %02x", bytes[i]];
    return out;
}

static NSArray *extendedSnapshotValues(void)
{
    return @[@{@"Direction Pad": @[@0.0f, @0.0f], @"Button A": @[@0.0f], @"Button B": @[@0.0f],
               @"Button X": @[@0.0f], @"Button Y": @[@0.0f], @"Left Shoulder": @[@0.0f],
               @"Right Shoulder": @[@0.0f], @"Left Thumbstick": @[@0.0f, @0.0f],
               @"Right Thumbstick": @[@0.0f, @0.0f], @"Left Trigger": @[@0.0f],
               @"Right Trigger": @[@0.0f], @"Left Thumbstick Button": @[@0.0f],
               @"Right Thumbstick Button": @[@0.0f]},
            @{@"Direction Pad": @[@0.5f, @(-0.25f)], @"Button A": @[@0.25f], @"Button B": @[@0.5f],
              @"Button X": @[@0.75f], @"Button Y": @[@1.0f], @"Left Shoulder": @[@0.125f],
              @"Right Shoulder": @[@0.375f], @"Left Thumbstick": @[@(-1.0f), @0.25f],
              @"Right Thumbstick": @[@0.5f, @(-0.5f)], @"Left Trigger": @[@0.625f],
              @"Right Trigger": @[@0.875f], @"Left Thumbstick Button": @[@1.0f],
              @"Right Thumbstick Button": @[@1.0f]},
            @{@"Direction Pad": @[@(-1.0f), @1.0f], @"Button A": @[@1.0f], @"Button B": @[@0.0f],
              @"Button X": @[@0.0f], @"Button Y": @[@0.5f], @"Left Shoulder": @[@0.5f],
              @"Right Shoulder": @[@0.0f], @"Left Thumbstick": @[@0.75f, @(-0.75f)],
              @"Right Thumbstick": @[@(-0.25f), @1.0f], @"Left Trigger": @[@0.0f],
              @"Right Trigger": @[@1.0f], @"Left Thumbstick Button": @[@1.0f],
              @"Right Thumbstick Button": @[@0.0f]}];
}

static NSArray *microSnapshotValues(void)
{
    return @[@{@"Direction Pad": @[@0.0f, @0.0f], @"Button A": @[@0.0f], @"Button X": @[@0.0f]},
            @{@"Direction Pad": @[@(-0.5f), @0.75f], @"Button A": @[@0.25f], @"Button X": @[@1.0f]},
            @{@"Direction Pad": @[@1.0f, @(-1.0f)], @"Button A": @[@1.0f], @"Button X": @[@0.0f]}];
}

static NSArray *snapshotObjectGroup(BOOL port)
{
    NSMutableArray *log = [NSMutableArray array];
    Class controllerClass = NSClassFromString(port ? @"RevenantHostGCController" : @"GCController");
    NSString *what = nil;

    id<LProfile> extended = [controllerClass controllerWithExtendedGamepad].extendedGamepad;
    [log addObject:[NSString stringWithFormat:@"extended untouched saveSnapshot %@",
                     hexData([(id<LSnapshot>)saveSnapshotOf(extended, &what) snapshotData])]];

    NSUInteger index = 0;
    for (NSDictionary *values in extendedSnapshotValues()) {
        GCExtendedGamepadSnapshotData fields;
        memset(&fields, 0, sizeof(fields));
        fields.dpadX = [values[@"Direction Pad"][0] floatValue];
        fields.dpadY = [values[@"Direction Pad"][1] floatValue];
        fields.buttonA = [values[@"Button A"][0] floatValue];
        fields.buttonB = [values[@"Button B"][0] floatValue];
        fields.buttonX = [values[@"Button X"][0] floatValue];
        fields.buttonY = [values[@"Button Y"][0] floatValue];
        fields.leftShoulder = [values[@"Left Shoulder"][0] floatValue];
        fields.rightShoulder = [values[@"Right Shoulder"][0] floatValue];
        fields.leftThumbstickX = [values[@"Left Thumbstick"][0] floatValue];
        fields.leftThumbstickY = [values[@"Left Thumbstick"][1] floatValue];
        fields.rightThumbstickX = [values[@"Right Thumbstick"][0] floatValue];
        fields.rightThumbstickY = [values[@"Right Thumbstick"][1] floatValue];
        fields.leftTrigger = [values[@"Left Trigger"][0] floatValue];
        fields.rightTrigger = [values[@"Right Trigger"][0] floatValue];
        fields.supportsClickableThumbsticks = YES;
        fields.leftThumbstickButton = [values[@"Left Thumbstick Button"][0] floatValue] > 0;
        fields.rightThumbstickButton = [values[@"Right Thumbstick Button"][0] floatValue] > 0;
        NSData *encoded = port ? revenantHost_NSDataFromGCExtendedGamepadSnapshotData(&fields)
                               : NSDataFromGCExtendedGamepadSnapshotData(&fields);
        [log addObject:[NSString stringWithFormat:@"extended set %lu encoder %@", (unsigned long)index, hexData(encoded)]];
        index++;
    }

    index = 0;
    for (NSDictionary *values in microSnapshotValues()) {
        GCMicroGamepadSnapshotData fields;
        memset(&fields, 0, sizeof(fields));
        fields.dpadX = [values[@"Direction Pad"][0] floatValue];
        fields.dpadY = [values[@"Direction Pad"][1] floatValue];
        fields.buttonA = [values[@"Button A"][0] floatValue];
        fields.buttonX = [values[@"Button X"][0] floatValue];
        NSData *reference = NSDataFromGCMicroGamepadSnapshotData(&fields);
        [log addObject:[NSString stringWithFormat:@"micro set %lu host encoder %@", (unsigned long)index, hexData(reference)]];

        NSString *built = @"no micro gamepad to save on this side";
        id<LProfile> live = [controllerClass controllerWithMicroGamepad].microGamepad;
        if (live != nil) {
            writeValues(live, values);
            built = [NSString stringWithFormat:@"%@", hexData([(id<LSnapshot>)saveSnapshotOf(live, &what) snapshotData])];
        }
        [log addObject:[NSString stringWithFormat:@"micro set %lu saveSnapshot %@", (unsigned long)index, built]];
        index++;
    }
    return log;
}

static NSArray *snapshotReadBackLines(void)
{
    NSMutableArray *log = [NSMutableArray array];
    NSString *snapshotName = @"RevenantHostGCExtendedGamepadSnapshot";
    NSString *microSnapshotName = @"RevenantHostGCMicroGamepadSnapshot";

    id<LProfile> extendedExtended = [NSClassFromString(@"RevenantHostGCController") controllerWithExtendedGamepad].extendedGamepad;
    [log addObject:[NSString stringWithFormat:@"extended -saveSnapshot is present: %@%@",
                     [extendedExtended respondsToSelector:@selector(saveSnapshot)] ? @"yes" : @"NO",
                     [extendedExtended respondsToSelector:@selector(saveSnapshot)] ? @"" : @" MISMATCH"]];

    {
        NSArray *names = @[@"Direction Pad", @"Button A", @"Button B", @"Button X", @"Button Y",
                           @"Left Shoulder", @"Right Shoulder", @"Left Thumbstick", @"Right Thumbstick",
                           @"Left Trigger", @"Right Trigger", @"Left Thumbstick Button",
                           @"Right Thumbstick Button"];
        NSUInteger round = 0;
        for (NSDictionary *values in extendedSnapshotValues()) {
            GCExtendedGamepadSnapshotData fields;
            memset(&fields, 0, sizeof(fields));
            fields.dpadX = [values[@"Direction Pad"][0] floatValue];
            fields.dpadY = [values[@"Direction Pad"][1] floatValue];
            fields.buttonA = [values[@"Button A"][0] floatValue];
            fields.buttonB = [values[@"Button B"][0] floatValue];
            fields.buttonX = [values[@"Button X"][0] floatValue];
            fields.buttonY = [values[@"Button Y"][0] floatValue];
            fields.leftShoulder = [values[@"Left Shoulder"][0] floatValue];
            fields.rightShoulder = [values[@"Right Shoulder"][0] floatValue];
            fields.leftThumbstickX = [values[@"Left Thumbstick"][0] floatValue];
            fields.leftThumbstickY = [values[@"Left Thumbstick"][1] floatValue];
            fields.rightThumbstickX = [values[@"Right Thumbstick"][0] floatValue];
            fields.rightThumbstickY = [values[@"Right Thumbstick"][1] floatValue];
            fields.leftTrigger = [values[@"Left Trigger"][0] floatValue];
            fields.rightTrigger = [values[@"Right Trigger"][0] floatValue];
            fields.supportsClickableThumbsticks = YES;
            fields.leftThumbstickButton = [values[@"Left Thumbstick Button"][0] floatValue] > 0;
            fields.rightThumbstickButton = [values[@"Right Thumbstick Button"][0] floatValue] > 0;

            id<LProfile> live = [NSClassFromString(@"RevenantHostGCController") controllerWithExtendedGamepad].extendedGamepad;
            writeValues(live, values);
            NSString *why = nil;
            NSString *reference = hexData(NSDataFromGCExtendedGamepadSnapshotData(&fields));
            NSString *encoded = hexData([(id<LSnapshot>)saveSnapshotOf(live, &why) snapshotData]);
            [log addObject:[NSString stringWithFormat:@"extended round trip %lu saveSnapshot %@ the host encoder says %@%@",
                             (unsigned long)round, encoded, reference,
                             [reference isEqualToString:encoded] ? @"" : @" MISMATCH"]];
            id rebuilt = [(id<LSnapshot>)[NSClassFromString(snapshotName) alloc]
                initWithSnapshotData:NSDataFromGCExtendedGamepadSnapshotData(&fields)];
            [log addObject:[NSString stringWithFormat:@"extended round trip %lu class %@",
                             (unsigned long)round, rebuilt ? NSStringFromClass([(NSObject *)rebuilt class]) : @"(nil)"]];
            for (NSString *name in names) {
                id element = [(id<LProfile>)rebuilt elements][name];
                NSString *want = elementWant(values[name]);
                NSString *got = elementReading(element);
                [log addObject:[NSString stringWithFormat:@"extended round trip %lu %@ want %@ got %@%@",
                                 (unsigned long)round, name, want, got,
                                 [got isEqualToString:want] ? @"" : @" MISMATCH"]];
            }
            round++;
        }

        NSUInteger microRound = 0;
        for (NSDictionary *values in microSnapshotValues()) {
            GCMicroGamepadSnapshotData fields;
            memset(&fields, 0, sizeof(fields));
            fields.dpadX = [values[@"Direction Pad"][0] floatValue];
            fields.dpadY = [values[@"Direction Pad"][1] floatValue];
            fields.buttonA = [values[@"Button A"][0] floatValue];
            fields.buttonX = [values[@"Button X"][0] floatValue];

            id rebuilt = [(id<LSnapshot>)[NSClassFromString(microSnapshotName) alloc]
                initWithSnapshotData:NSDataFromGCMicroGamepadSnapshotData(&fields)];
            [log addObject:[NSString stringWithFormat:@"micro round trip %lu class %@",
                             (unsigned long)microRound, rebuilt ? NSStringFromClass([(NSObject *)rebuilt class]) : @"(nil)"]];
            for (NSString *name in @[@"Direction Pad", @"Button A", @"Button X"]) {
                id element = [(id<LProfile>)rebuilt elements][name];
                NSString *want = elementWant(values[name]);
                NSString *got = elementReading(element);
                [log addObject:[NSString stringWithFormat:@"micro round trip %lu %@ want %@ got %@%@",
                                 (unsigned long)microRound, name, want, got,
                                 [got isEqualToString:want] ? @"" : @" MISMATCH"]];
            }
            microRound++;
        }
    }
    return log;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class host = NSClassFromString(@"GCController"), port = NSClassFromString(@"RevenantHostGCController");
        int failures = 0, checks = 0;
        for (int micro = 0; micro < 2; micro++) {
            NSArray *a = drive(host, micro), *b = drive(port, micro);
            printf("%s: %lu lines from the host, %lu from the port\n", micro ? "micro" : "extended", (unsigned long)a.count, (unsigned long)b.count);
            int shown = 0;
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    if (shown++ < 12)
                        printf("DIFFERENT line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *a = [keyboardKeys(@"GCKeyboardInput", @"RevenantHostGCKeyboardInput") arrayByAddingObjectsFromArray:keyCodeGroup(false)],
                     *b = [keyboardKeys(@"RevenantHostGCKeyboardInput", @"GCKeyboardInput") arrayByAddingObjectsFromArray:keyCodeGroup(true)];
            printf("keyboard: %lu lines from the host, %lu from the port\n", (unsigned long)a.count, (unsigned long)b.count);
            int shownKeyboard = 0;
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    if (shownKeyboard++ < 24)
                        printf("DIFFERENT keyboard line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *a = hardwareGroup(false), *b = hardwareGroup(true);
            printf("hardware: %lu lines from the host, %lu from the port\n", (unsigned long)a.count, (unsigned long)b.count);
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    printf("DIFFERENT hardware line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *a = [paddlesGroup(false) arrayByAddingObjectsFromArray:touchpadsGroup(false)],
                     *b = [paddlesGroup(true) arrayByAddingObjectsFromArray:touchpadsGroup(true)];
            printf("gamepad extras: %lu lines from the host, %lu from the port\n", (unsigned long)a.count, (unsigned long)b.count);
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    printf("DIFFERENT gamepad extras line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *a = triggerGroup(false), *b = triggerGroup(true);
            printf("adaptive trigger: %lu lines from the host, %lu from the port\n", (unsigned long)a.count, (unsigned long)b.count);
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    printf("DIFFERENT trigger line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *a = touchpadState(false), *b = touchpadState(true);
            printf("touchpad state: %lu lines from the host, %lu from the port\n", (unsigned long)a.count, (unsigned long)b.count);
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    printf("DIFFERENT touchpad state line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *a = [gamepadInfo(@"GCGamepad") arrayByAddingObjectsFromArray:[gamepadInfo(@"GCExtendedGamepad") arrayByAddingObjectsFromArray:gamepadInfo(@"GCMicroGamepad")]];
            NSArray *b = [gamepadInfo(@"RevenantHostGCGamepad") arrayByAddingObjectsFromArray:[gamepadInfo(@"RevenantHostGCExtendedGamepad") arrayByAddingObjectsFromArray:gamepadInfo(@"RevenantHostGCMicroGamepad")]];
            printf("gamepad: %lu lines from the host, %lu from the port\n", (unsigned long)a.count, (unsigned long)b.count);
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    printf("DIFFERENT gamepad line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *a = snapshotFunctionGroup(false), *b = snapshotFunctionGroup(true);
            printf("snapshot functions: %lu lines from the host, %lu from the port\n", (unsigned long)a.count, (unsigned long)b.count);
            int shown = 0;
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    if (shown++ < 20)
                        printf("DIFFERENT snapshot function line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *a = snapshotObjectGroup(false), *b = snapshotObjectGroup(true);
            printf("snapshot objects: %lu lines from the host, %lu from the port\n", (unsigned long)a.count, (unsigned long)b.count);
            int shown = 0;
            for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
                checks++;
                NSString *x = i < a.count ? a[i] : @"(none)", *y = i < b.count ? b[i] : @"(none)";
                if (![x isEqual:y]) {
                    failures++;
                    if (shown++ < 20)
                        printf("DIFFERENT snapshot object line %lu:\n  host %s\n  port %s\n", (unsigned long)i, x.UTF8String, y.UTF8String);
                }
            }
        }
        {
            NSArray *lines = snapshotReadBackLines();
            printf("snapshot read back: %lu lines from the port\n", (unsigned long)lines.count);
            for (NSString *line in lines) {
                checks++;
                if ([line rangeOfString:@" MISMATCH"].location != NSNotFound) {
                    failures++;
                    printf("  %s\n", line.UTF8String);
                }
            }
        }
        {
            NSArray *lines = touchpadElements();
            printf("touchpad elements: %lu lines from the port\n", (unsigned long)lines.count);
            for (NSString *line in lines) {
                checks++;
                printf("  %s\n", line.UTF8String);
            }
        }
        printf("%d checks, %d different\n", checks, failures);
        if (checks < 1000) {
            printf("the comparison examined %d lines, which is too few to be a verdict\n", checks);
            return 1;
        }
        return failures != 0;
    }
}
