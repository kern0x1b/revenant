#import "colors13_scenario.h"

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        [[colors_scenario() componentsJoinedByString:@"\n"] writeToFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
}
