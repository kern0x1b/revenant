#import <UIKit/UIKit.h>
#import "check.h"
#import "flowauto-cases.h"

void charon_windowed_run(UIWindow *window);

void charon_windowed_run(UIWindow *window)
{
    // The host rounds a self-sized cell to the pixels of the display the window is on, and device/flowauto.m holds
    // a phone at scale 2 to these answers within 0.01: answers taken on a display at scale 1 are not written.
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
