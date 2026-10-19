#import "hover16_scenario.h"

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
        [window addSubview:host];
        UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 120, 200, 44)];
        [window addSubview:bar];
        UITextField *field = nil;
        for (UIView *sub in bar.subviews)
            if ([sub isKindOfClass:[UITextField class]])
                field = (UITextField *)sub;
        NSArray *lines = hover16_scenario([UIHoverGestureRecognizer class], host, bar, field);
        NSString *text = [lines componentsJoinedByString:@"\n"];
        [text writeToFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
}
