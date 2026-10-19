#import <GameController/GameController.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *f(float value)
{
    return value == 0 ? @"0" : [NSString stringWithFormat:@"%.9g", value];
}

static void spin(void)
{
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
}

static NSString *sorted(NSSet *set)
{
    return [[[set allObjects] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
}

static void hookButton(GCControllerButtonInput *button, NSString *name, NSMutableArray *log)
{
    button.valueChangedHandler = ^(GCControllerButtonInput *b, float v, BOOL p) { [log addObject:[NSString stringWithFormat:@"%@ value %@ %d", name, f(v), p]]; };
    button.touchedChangedHandler = ^(GCControllerButtonInput *b, float v, BOOL p, BOOL t) { [log addObject:[NSString stringWithFormat:@"%@ touched %@ %d %d", name, f(v), p, t]]; };
    button.pressedChangedHandler = ^(GCControllerButtonInput *b, float v, BOOL p) { [log addObject:[NSString stringWithFormat:@"%@ pressed %@ %d", name, f(v), p]]; };
}

static NSArray *script(void)
{
    NSMutableArray *log = [NSMutableArray array];
    GCController *controller = [GCController controllerWithExtendedGamepad];
    GCExtendedGamepad *pad = controller.extendedGamepad;
    [log addObject:[NSString stringWithFormat:@"controller %@ %@ player=%ld snapshot=%d attached=%d", controller.vendorName, controller.productCategory, (long)controller.playerIndex, controller.isSnapshot, controller.isAttachedToDevice]];
    [log addObject:[NSString stringWithFormat:@"counts %lu %lu %lu %lu %lu", (unsigned long)pad.elements.count, (unsigned long)pad.buttons.count, (unsigned long)pad.axes.count, (unsigned long)pad.dpads.count, (unsigned long)pad.allElements.count]];
    [log addObject:[NSString stringWithFormat:@"A %@ %@ %@ %d", pad.buttonA.localizedName, pad.buttonA.sfSymbolsName, sorted(pad.buttonA.aliases), pad.buttonA.isAnalog]];
    [log addObject:[NSString stringWithFormat:@"paddle %@ %@", sorted([pad.elements[@"Paddle 1"] aliases]), [pad.elements[@"Paddle 1"] localizedName]]];
    [log addObject:[NSString stringWithFormat:@"options %d home %d menu %d", pad.buttonOptions.isBoundToSystemGesture, pad.buttonHome.isBoundToSystemGesture, pad.buttonMenu.isBoundToSystemGesture]];
    [log addObject:[NSString stringWithFormat:@"same profile %d %d %d", (id)controller.gamepad == pad, controller.microGamepad == (id)pad, controller.physicalInputProfile == pad]];
    hookButton(pad.buttonA, @"A", log);
    float sweep[] = {0.001f, 0.005f, 0.1f, 0.001953125f, 0.002f, 0, 1.7f, -0.3f, 1, 1, 0};
    for (size_t i = 0; i < sizeof sweep / sizeof sweep[0]; i++) {
        [pad.buttonA setValue:sweep[i]];
        spin();
        [log addObject:[NSString stringWithFormat:@"A set %@ -> %@ %d %d", f(sweep[i]), f(pad.buttonA.value), pad.buttonA.isPressed, pad.buttonA.isTouched]];
    }
    GCControllerDirectionPad *stick = pad.leftThumbstick;
    hookButton(stick.up, @"up", log);
    hookButton(stick.down, @"down", log);
    hookButton(stick.left, @"left", log);
    hookButton(stick.right, @"right", log);
    stick.xAxis.valueChangedHandler = ^(GCControllerAxisInput *a, float v) { [log addObject:[NSString stringWithFormat:@"x %@", f(v)]]; };
    stick.yAxis.valueChangedHandler = ^(GCControllerAxisInput *a, float v) { [log addObject:[NSString stringWithFormat:@"y %@", f(v)]]; };
    stick.valueChangedHandler = ^(GCControllerDirectionPad *d, float x, float y) { [log addObject:[NSString stringWithFormat:@"stick %@ %@", f(x), f(y)]]; };
    float pairs[][2] = {{0.7f, 0.2f}, {-1.5f, 0.9f}, {0.3f, 0.9f}, {0.3f, 0.9f}, {1e-6f, 0}, {0, 0}, {0.2f, -0.5f}, {2, 2}, {0, 0}};
    for (size_t i = 0; i < sizeof pairs / sizeof pairs[0]; i++) {
        [stick setValueForXAxis:pairs[i][0] yAxis:pairs[i][1]];
        spin();
        [log addObject:[NSString stringWithFormat:@"stick set %@ %@ -> x %@ y %@ up %@ down %@ left %@ right %@ %d%d", f(pairs[i][0]), f(pairs[i][1]), f(stick.xAxis.value), f(stick.yAxis.value), f(stick.up.value), f(stick.down.value),
                        f(stick.left.value), f(stick.right.value), stick.up.isPressed, stick.up.isTouched]];
    }
    [pad.buttonB setValue:0.5f];
    [pad.rightThumbstick setValueForXAxis:-0.4f yAxis:0.6f];
    GCController *other = [GCController controllerWithExtendedGamepad];
    [other.extendedGamepad setStateFromExtendedGamepad:pad];
    [log addObject:[NSString stringWithFormat:@"copied B %@ right stick %@ %@ left stick %@ %@", f(other.extendedGamepad.buttonB.value), f(other.extendedGamepad.rightThumbstick.xAxis.value),
                    f(other.extendedGamepad.rightThumbstick.yAxis.value), f(other.extendedGamepad.leftThumbstick.xAxis.value), f(other.extendedGamepad.leftThumbstick.yAxis.value)]];
    GCExtendedGamepad *captured = [pad capture];
    [log addObject:[NSString stringWithFormat:@"captured %d %@ %d", captured.controller == nil, f(captured.buttonB.value), [captured isMemberOfClass:[pad class]]]];
    controller.playerIndex = GCControllerPlayerIndex3;
    GCController *twin = [controller capture];
    [log addObject:[NSString stringWithFormat:@"capture controller %@ %d player=%ld", twin.vendorName, twin.isSnapshot, (long)twin.playerIndex]];

    GCController *micro = [GCController controllerWithMicroGamepad];
    GCMicroGamepad *remote = micro.microGamepad;
    [log addObject:[NSString stringWithFormat:@"micro %@ %@ ext=%d counts %lu %lu analogA=%d dpad %@", micro.vendorName, micro.productCategory, micro.extendedGamepad != nil, (unsigned long)remote.elements.count, (unsigned long)remote.allElements.count,
                    remote.buttonA.isAnalog, remote.dpad.localizedName]];
    GCMotion *motion = controller.motion;
    GCMotion *remoteMotion = micro.motion;
    [log addObject:[NSString stringWithFormat:@"motion %g %g %g attitude %g,%g,%g,%g has %d %d", motion.gravity.x, motion.gravity.y, motion.gravity.z, motion.attitude.x, motion.attitude.y, motion.attitude.z, motion.attitude.w,
                    motion.hasAttitude, remoteMotion.hasAttitude]];
    __block int changed = 0;
    motion.valueChangedHandler = ^(GCMotion *m) { changed++; };
    [motion setGravity:(GCAcceleration){0, -1, 0}];
    spin();
    [log addObject:[NSString stringWithFormat:@"motion set gravity %g fired %d", motion.gravity.y, changed]];
    [motion setStateFromMotion:motion];
    [motion setStateFromMotion:remoteMotion];
    spin();
    [log addObject:[NSString stringWithFormat:@"motion copied fired %d gravity %g attitude w %g", changed, motion.gravity.z, motion.attitude.w]];
    return log;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSArray *lines = script();
        if (argc > 1 && !strcmp(argv[1], "--print")) {
            for (NSString *line in lines)
                printf("    @\"%s\",\n", [[line stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""] UTF8String]);
            return 0;
        }
        if (argc > 1)
            charon_log_to(@(argv[1]));
#include "gamecontroller-model-expected.h"
        CHECK_EQUAL(image_of([GCControllerButtonInput class]), @"libGameControllerBackports.dylib", "the button comes from the backports");
        CHECK_EQUAL(image_of([GCExtendedGamepad class]), @"libGameControllerBackports.dylib", "the extended gamepad comes from the backports");
        CHECK_EQUAL(image_of([GCMotion class]), @"libGameControllerBackports.dylib", "the motion comes from the backports");
        CHECK_EQUAL(image_of([GCPhysicalInputProfile class]), @"libGameControllerBackports.dylib", "the base of the profiles comes from the backports");
        CHECK(lines.count == expected.count, "the script gives as many lines as the host gave");
        for (NSUInteger i = 0; i < MIN(lines.count, expected.count); i++)
            CHECK_EQUAL(lines[i], expected[i], [lines[i] UTF8String]);
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
