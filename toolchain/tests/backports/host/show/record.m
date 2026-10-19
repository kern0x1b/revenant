#import <UIKit/UIKit.h>
#import "show-cases.h"

void charon_windowed_run(UIWindow *window);

void charon_windowed_run(UIWindow *window)
{
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    show_run(window, ^(NSString *name, NSString *value) {
        records[name] = value;
        printf("%s: %s\n", name.UTF8String, value.UTF8String); fflush(stdout);
    });
    [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("SHOW_RECORDS")) atomically:YES];
}
