#import <Foundation/Foundation.h>
#import "vtclass-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        vtclass_run(^(NSString *name, NSString *value) { records[name] = value ?: [NSNull null]; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL]
            writeToFile:@(getenv("VTCLASS_RECORDS")) atomically:YES];
    }
    return 0;
}
