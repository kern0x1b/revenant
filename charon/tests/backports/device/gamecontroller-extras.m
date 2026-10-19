#import <GameController/GameController.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        NSArray *names = @[@"GCColor", @"GCEventViewController", @"GCXboxGamepad", @"GCDualShockGamepad", @"GCControllerTouchpad", @"GCDeviceBattery", @"GCDeviceLight", @"GCDeviceHaptics",
                           @"GCKeyboardInput", @"GCMouseInput", @"GCDeviceCursor", @"GCDirectionalGamepad", @"GCDualSenseGamepad", @"GCDualSenseAdaptiveTrigger"];
        int carried = 0;
        for (NSString *name in names)
            carried += [image_of(NSClassFromString(name)) isEqualToString:@"libGameControllerBackports.dylib"];
        CHECK(carried == 14, "the 14 classes come from the backports");
        CHECK([NSClassFromString(@"GCXboxGamepad") isSubclassOfClass:[GCExtendedGamepad class]] && [NSClassFromString(@"GCDirectionalGamepad") isSubclassOfClass:[GCMicroGamepad class]]
              && [NSClassFromString(@"GCKeyboardInput") isSubclassOfClass:[GCPhysicalInputProfile class]] && [NSClassFromString(@"GCDeviceCursor") isSubclassOfClass:[GCControllerDirectionPad class]]
              && [NSClassFromString(@"GCDualSenseAdaptiveTrigger") isSubclassOfClass:[GCControllerButtonInput class]] && [NSClassFromString(@"GCControllerTouchpad") isSubclassOfClass:[GCControllerElement class]],
              "the classes of the devices have the superclasses the header gives");
        CHECK(![[GCController controllerWithExtendedGamepad].extendedGamepad isKindOfClass:NSClassFromString(@"GCXboxGamepad")], "a controller of software is not an Xbox gamepad");
        GCColor *color = [[GCColor alloc] initWithRed:0.25f green:0.5f blue:0.75f];
        CHECK(color.red == 0.25f && color.green == 0.5f && color.blue == 0.75f, "a colour holds what it is given");
        CHECK_EQUAL(color.description, @"<GCColor r=0.250000 g=0.500000 b=0.750000>", "and describes itself as the host does");
        GCColor *outside = [[GCColor alloc] initWithRed:-1 green:2 blue:0.5f];
        CHECK(outside.red == -1 && outside.green == 2, "it does not clamp");
        GCColor *copy = [color copy];
        CHECK(copy != color && copy.red == 0.25f && copy.blue == 0.75f && ![copy isEqual:color], "a copy is a new object with the same components and is not equal to it, as on the host");
        CHECK([GCColor supportsSecureCoding], "it supports secure coding");
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:color];
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
        NSDictionary *object = plist[@"$objects"][1];
        CHECK([object[@"red"] floatValue] == 0.25f && [object[@"green"] floatValue] == 0.5f && [object[@"blue"] floatValue] == 0.75f, "it encodes red, green and blue as reals");
        GCColor *back = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        CHECK(back.red == 0.25f && back.green == 0.5f && back.blue == 0.75f, "and decodes them");
        GCEventViewController *controller = [[GCEventViewController alloc] init];
        CHECK(!controller.controllerUserInteractionEnabled, "the event view controller starts with controller events kept from the responder chain");
        controller.controllerUserInteractionEnabled = YES;
        CHECK(controller.controllerUserInteractionEnabled && [controller isKindOfClass:[UIViewController class]], "it keeps what is set and is a view controller");
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
