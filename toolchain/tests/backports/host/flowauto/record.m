#import <UIKit/UIKit.h>
#import "check.h"
#import "flowauto-cases.h"

void charon_windowed_run(UIWindow *window);

void charon_windowed_run(UIWindow *window)
{
    if (window.screen.scale != 2) {
        printf("FAIL: the window is on a display at scale %g, not 2; nothing recorded\n", window.screen.scale);
        charon_failures++;
        return;
    }
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    flowauto_run(window, ^(NSString *name, NSString *value) {
        records[name] = value;
        printf("%s: %s\n", name.UTF8String, value.UTF8String);
    });
    [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("FLOWAUTO_RECORDS")) atomically:YES];
}
