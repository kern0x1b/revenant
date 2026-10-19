// The host's own CloudKit, asked the record cases and printing the answers as JSON.
//
// Built as a Mac Catalyst binary against the iOSSupport frameworks in the macOS SDK, so what answers
// is the host's *iOS* CloudKit and not the macOS one, and no network or account is touched: every
// case builds its objects in memory.

#import <Foundation/Foundation.h>
#import "records-cases.h"

int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        CharonRecordCases(out);
        NSData *json = [NSJSONSerialization dataWithJSONObject:out
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:NULL];
        [json writeToFile:@(getenv("CLOUDKIT_RECORDS")) atomically:YES];
    }
    return 0;
}
