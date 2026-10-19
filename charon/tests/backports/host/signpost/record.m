#import <Foundation/Foundation.h>
#import "signpost-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        signpost_run(^(NSString *name, NSString *value) { records[name] = value ?: [NSNull null]; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL]
            writeToFile:@(getenv("SIGNPOST_RECORDS")) atomically:YES];
    }
    return 0;
}
