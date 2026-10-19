#import "images13_scenario.h"

void revenant_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        [[images_scenario(make_bundle(), [UIImageSymbolConfiguration class], [UIImageConfiguration class]) componentsJoinedByString:@"\n"] writeToFile:[NSString stringWithUTF8String:getenv("REVENANT_EXPECTED")] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
}
