#import <UIKit/UIKit.h>
#import "layoutguide-cases.h"

void charon_windowed_run(UIWindow *window);

void charon_windowed_run(UIWindow *window)
{
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    layoutguide_run(window, ^(NSString *name, NSString *value) {
        records[name] = value;
        printf("%s: %s\n", name.UTF8String, value.UTF8String);
    });
    [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("LAYOUTGUIDE_RECORDS")) atomically:YES];
}
