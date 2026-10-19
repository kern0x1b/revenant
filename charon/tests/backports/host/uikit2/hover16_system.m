// hover16_system.m - the recorder: this process links none of the port's code, so what it writes is
// the host's own UIKit and nothing else. uikit2/run.sh builds it into its own bundle, runs it with
// CHARON_EXPECTED pointing at a file, and only then runs hover16_test.m in a process that does link
// the port, with that file as what the port has to match.
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
