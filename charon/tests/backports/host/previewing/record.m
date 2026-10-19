#import <UIKit/UIKit.h>
#import "previewing-cases.h"

void charon_windowed_run(UIWindow *window);

void charon_windowed_run(UIWindow *window)
{
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    previewing_run(window, ^(NSString *name, NSString *value) {
        records[name] = value;
        printf("%s: %s\n", name.UTF8String, value.UTF8String); fflush(stdout);
    });
    [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("PREVIEWING_RECORDS")) atomically:YES];
}
