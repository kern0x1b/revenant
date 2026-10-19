#import <UIKit/UIKit.h>
#import "tail3-cases.h"

void charon_windowed_run(UIWindow *window);

void charon_windowed_run(UIWindow *window)
{
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    tail3_run(^(NSString *name, NSString *value) {
        records[name] = value;
        printf("%s: %s\n", name.UTF8String, value.UTF8String);
    });
    [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("TAIL3_RECORDS")) atomically:YES];
}
