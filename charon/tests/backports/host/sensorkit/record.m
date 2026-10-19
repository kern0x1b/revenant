#import <Foundation/Foundation.h>
#import "sensorkit-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        sensorkit_run(^(NSString *name, NSString *value) { records[name] = value ?: [NSNull null]; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL]
            writeToFile:@(getenv("SENSORKIT_RECORDS")) atomically:YES];
    }
    return 0;
}
