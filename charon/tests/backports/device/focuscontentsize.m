#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"

static NSString *image_of_class(Class class)
{
    Dl_info info;
    if (!class || !dladdr((__bridge const void *)class, &info) || !info.dli_fname)
        return @"<missing>";
    return @(info.dli_fname).lastPathComponent;
}

static NSString *image_of_method(Class class, SEL selector)
{
    Method method = class_getInstanceMethod(class, selector);
    if (!method)
        return @"<missing>";
    Dl_info info;
    if (!dladdr((void *)method_getImplementation(method), &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static void check_focus(void)
{
    Class coordinator = NSClassFromString(@"UIFocusAnimationCoordinator");
    charon_check(coordinator != Nil, "UIFocusAnimationCoordinator is there", nil);
    charon_check([image_of_class(coordinator) isEqualToString:@"libUIKitBackports.dylib"],
                 "UIFocusAnimationCoordinator comes from the backports", image_of_class(coordinator));
    if (!coordinator)
        return;

    UIFocusAnimationCoordinator *made = [[UIFocusAnimationCoordinator alloc] init];
    __block NSMutableArray *order = [NSMutableArray array];
    [made addCoordinatedAnimations:^{ [order addObject:@"animations"]; } completion:^{ [order addObject:@"completion"]; }];
    charon_check([order isEqualToArray:@[@"animations", @"completion"]],
                 "the animations run and then the completion, at once", [order componentsJoinedByString:@","]);

    order = [NSMutableArray array];
    [made addCoordinatedAnimations:nil completion:^{ [order addObject:@"completion"]; }];
    charon_check([order isEqualToArray:@[@"completion"]], "a completion alone is run", [order componentsJoinedByString:@","]);

    [made addCoordinatedAnimations:nil completion:nil];
    charon_check(YES, "both blocks nil is quiet", nil);
}

static void check_adjusting(void)
{
    Protocol *adjusting = NSProtocolFromString(@"UIContentSizeCategoryAdjusting");
    charon_check(adjusting != NULL, "UIContentSizeCategoryAdjusting is a protocol the process knows", nil);
    for (NSString *name in @[@"UILabel", @"UITextField", @"UITextView"]) {
        Class class = NSClassFromString(name);
        charon_check(class != Nil, [NSString stringWithFormat:@"%@ is there", name].UTF8String, nil);
        for (NSString *selector in @[@"adjustsFontForContentSizeCategory", @"setAdjustsFontForContentSizeCategory:"]) {
            NSString *image = image_of_method(class, NSSelectorFromString(selector));
            charon_check([image isEqualToString:@"libUIKitBackports.dylib"],
                         [NSString stringWithFormat:@"-[%@ %@] comes from the backports", name, selector].UTF8String, image);
        }
        charon_check(adjusting && class_conformsToProtocol(class, adjusting),
                     [NSString stringWithFormat:@"%@ says it adopts UIContentSizeCategoryAdjusting", name].UTF8String, nil);
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        (void)argc;
        (void)argv;
        check_focus();
        check_adjusting();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
