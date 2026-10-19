// The port's record value half, asked the same questions records-host.m asks the host.
//
// One cases file, two builds: this one compiles the port's own objects with no CloudKit framework
// linked at all, and the classes come from packages/a/apple-backports/CloudKit. The answers are
// written where compare.py expects them, and a reader that lives in the same tree as the code it
// checks would be a reader that can share its mistake, so the comparison is a script that reads both
// files and does not import either.

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
