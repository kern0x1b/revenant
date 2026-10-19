#import <Foundation/Foundation.h>
#import "videotoolbox-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        videotoolbox_run(^(NSString *name, NSString *value) { records[name] = value ?: [NSNull null]; });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL]
            writeToFile:@(getenv("VIDEOTOOLBOX_RECORDS")) atomically:YES];
    }
    return 0;
}
