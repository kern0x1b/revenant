#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static BOOL survives(void (^block)(void))
{
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"raised %@: %@", exception.name, exception.reason);
        return NO;
    }
}

@interface CapabilityDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CapabilityDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"capability.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"capability.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self run]; });
    return YES;
}

- (void)run
{
    CHECK(survives(^{
        UISelectionFeedbackGenerator *selection = [[UISelectionFeedbackGenerator alloc] init];
        [selection prepare];
        [selection selectionChanged];
        UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [impact prepare];
        [impact impactOccurred];
        UINotificationFeedbackGenerator *notification = [[UINotificationFeedbackGenerator alloc] init];
        [notification prepare];
        [notification notificationOccurred:UINotificationFeedbackTypeSuccess];
    }), "the three feedback generators can be made, prepared and fired");

    CHECK(survives(^{
        NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"local.charon.test"];
        activity.title = @"title";
        activity.userInfo = @{@"a": @1};
        activity.eligibleForHandoff = YES;
        activity.eligibleForSearch = YES;
        [activity becomeCurrent];
        [activity resignCurrent];
        [activity invalidate];
        CHECK_EQUAL(activity.activityType, @"local.charon.test", "a user activity keeps its type");
    }), "a user activity can be made, made current and ended");

    CHECK(survives(^{
        UIApplicationShortcutItem *item = [[UIApplicationShortcutItem alloc] initWithType:@"a" localizedTitle:@"A" localizedSubtitle:nil icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeSearch] userInfo:nil];
        [UIApplication sharedApplication].shortcutItems = @[item];
        CHECK([[UIApplication sharedApplication].shortcutItems.firstObject.type isEqual:@"a"], "the shortcut items an application sets are kept");
        [UIApplication sharedApplication].shortcutItems = nil;
    }), "shortcut items and their icons can be made and set");

    CHECK(survives(^{
        UITextField *field = [[UITextField alloc] init];
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:@"x" style:UIBarButtonItemStylePlain target:nil action:NULL];
        UIBarButtonItemGroup *group = [[UIBarButtonItemGroup alloc] initWithBarButtonItems:@[button] representativeItem:nil];
        field.inputAssistantItem.leadingBarButtonGroups = @[group];
        CHECK(field.inputAssistantItem.leadingBarButtonGroups.count == 1, "the groups an assistant item is given are kept");
    }), "a bar button group can be put on a text field's assistant item");

    CHECK(survives(^{
        UIView *view = [[UIView alloc] init];
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:@"do" target:self selector:@selector(description)];
        view.accessibilityCustomActions = @[action];
        CHECK(view.accessibilityCustomActions.count == 1, "the custom actions of a view are kept");
    }), "an accessibility custom action can be made and set");

    CHECK(survives(^{
        NSExtensionItem *item = [[NSExtensionItem alloc] init];
        item.attributedTitle = [[NSAttributedString alloc] initWithString:@"t"];
        item.attachments = @[[[NSItemProvider alloc] initWithItem:@"x" typeIdentifier:@"public.text"]];
        CHECK(item.attachments.count == 1, "an extension item keeps its attachments");
    }), "an extension item can be made");

    CHECK(survives(^{
        UIViewController *controller = [[UIViewController alloc] init];
        controller.modalPresentationStyle = UIModalPresentationCustom;
        UIPercentDrivenInteractiveTransition *transition = [[UIPercentDrivenInteractiveTransition alloc] init];
        [transition updateInteractiveTransition:0.5];
        [transition cancelInteractiveTransition];
        (void)controller.presentationController;
    }), "a percent driven transition and the presentation controller of a view controller can be asked for");

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"capability.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CapabilityDelegate class]));
    }
}
