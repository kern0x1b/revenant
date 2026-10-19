#import "controlmenus_scenario.h"

// The port publishes its own control-with-actions implementation as a name of its own. The harness renames
// every exported C symbol an object defines, so the name here is the **harness's** name for it - the same
// convention this test already uses for classes, where it asks for CharonHostUIAction rather than UIAction.
// Named without the prefix, it is the same -D mistake the review opened with, one level up.
extern UISegmentedControl *CharonHostcharon_control_init_with_actions(UISegmentedControl *, CGRect, NSArray *);

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        Class ourAction = NSClassFromString(@"CharonHostUIAction"), ourMenu = NSClassFromString(@"CharonHostUIMenu");
        charon_check(ourAction && ourMenu, "the port's classes are linked under their host names", @"missing");
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        ur_agree(@"control menus, bar button items and segmented controls", menu_scenario(ourAction, ourMenu, &CharonHostcharon_control_init_with_actions), [expected componentsSeparatedByString:@"\n"]);
    }
}
