#import <UIKit/UIKit.h>
#import "sheet-cases.h"

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        sheet_api_run(^(NSString *name, NSString *value) {
            records[name] = value;
            printf("%s: %s\n", name.UTF8String, value.UTF8String);
        });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("SHEET_RECORDS")) atomically:YES];
    }
    return 0;
}
