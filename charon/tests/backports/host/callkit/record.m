#import <Foundation/Foundation.h>
#import "callkit-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        callkit_run(^(NSString *name, NSString *value) { records[name] = value; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("CALLKIT_RECORDS")) atomically:YES];
    }
    return 0;
}
