#import "controlactions_scenario.h"

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        Class ourAction = NSClassFromString(@"CharonHostUIAction");
        charon_check(ourAction != Nil, "the port's action is linked under its host name", @"missing");
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        ur_agree(@"control actions", control_scenario(ourAction), [expected componentsSeparatedByString:@"\n"]);
    }
}
