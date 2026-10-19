#import <UIKit/UIKit.h>
#import "insetref-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        insetref_run(nil, ^(NSString *name, NSString *value) { records[name] = value; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("INSETREF_RECORDS")) atomically:YES];
    }
    return 0;
}
