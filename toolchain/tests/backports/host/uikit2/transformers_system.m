#import "transformers_scenario.h"

void revenant_windowed_run(UIWindow *window)
{
    (void)window;
    @autoreleasepool {
        [[transformers_scenario() componentsJoinedByString:@"\n"] writeToFile:[NSString stringWithUTF8String:getenv("REVENANT_EXPECTED")] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
}
