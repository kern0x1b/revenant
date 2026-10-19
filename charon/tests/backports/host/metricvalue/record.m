#import <Foundation/Foundation.h>
#import "metricvalue-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        metricvalue_run(^(NSString *name, NSString *value) { records[name] = value ?: [NSNull null]; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL]
            writeToFile:@(getenv("METRICVALUE_RECORDS")) atomically:YES];
    }
    return 0;
}
