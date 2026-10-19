#import "darkstyle_scenario.h"

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        [[darkstyle_scenario(window) componentsJoinedByString:@"\n"] writeToFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
}
