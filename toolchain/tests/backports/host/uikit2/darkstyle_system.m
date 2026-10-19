#import "darkstyle_scenario.h"

void revenant_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        [[darkstyle_scenario(window) componentsJoinedByString:@"\n"] writeToFile:[NSString stringWithUTF8String:getenv("REVENANT_EXPECTED")] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
}
