#import "controlmenus_scenario.h"

extern UISegmentedControl *RevenantHostrevenant_control_init_with_actions(UISegmentedControl *, CGRect, NSArray *);

void revenant_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        Class ourAction = NSClassFromString(@"RevenantHostUIAction"), ourMenu = NSClassFromString(@"RevenantHostUIMenu");
        revenant_check(ourAction && ourMenu, "the port's classes are linked under their host names", @"missing");
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("REVENANT_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        ur_agree(@"control menus, bar button items and segmented controls", menu_scenario(ourAction, ourMenu, &RevenantHostrevenant_control_init_with_actions), [expected componentsSeparatedByString:@"\n"]);
    }
}
