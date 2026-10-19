#import <UIKit/UIKit.h>
#import "pasteboard10-cases.h"

void charon_windowed_run(UIWindow *window);

void charon_windowed_run(UIWindow *window)
{
    (void)window;
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    pasteboard10_run(^(NSString *name, NSString *value) {
        records[name] = value;
        printf("%s: %s\n", name.UTF8String, value.UTF8String); fflush(stdout);
    });
    [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("PASTEBOARD10_RECORDS")) atomically:YES];
}
