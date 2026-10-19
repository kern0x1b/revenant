#import <Foundation/Foundation.h>
#import "records-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        RevenantRecordCases(out);
        NSData *json = [NSJSONSerialization dataWithJSONObject:out
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:NULL];
        [json writeToFile:@(getenv("CLOUDKIT_RECORDS")) atomically:YES];
    }
    return 0;
}
