#import <Foundation/Foundation.h>
#import "vision-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        vision_run(^(NSString *name, NSString *value) { records[name] = value; },
                   vision_coreml_models());
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("VISION_RECORDS")) atomically:YES];
    }
    return 0;
}
