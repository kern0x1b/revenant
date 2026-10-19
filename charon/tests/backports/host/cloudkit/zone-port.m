// The port's own CKRecordZone, asked the questions database-host.m asks the host.
//
// One cases file, two builds: this one links packages/a/apple-backports/CloudKit with NO CloudKit
// framework at all and takes the CK names from this package, which is what makes the comparison a
// statement about behaviour rather than about a re-implementation. The answers go where compare.py
// reads them, and compare.py is a script that reads both files and imports neither.
//
// No CloudKit header is imported here either: database-cases.h declares the surface, so this file and
// the host's are the same code with a different library behind it.
//
//     clang -target arm64-apple-ios13.1-macabi -isysroot "$(xcrun --show-sdk-path --sdk macosx)" \
//         -fobjc-arc -I packages/a/apple-backports -I packages/a/apple-backports/CloudKit \
//         -o zone-port zone-port.m <the port's .o files, no -framework CloudKit>

#import <Foundation/Foundation.h>

#import "database-cases.h"

int main(void)
{
    @autoreleasepool {
        NSString *path = @(getenv("CLOUDKIT_ZONE"));
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        out[@"conditions"] = @"the port's own objects, no CloudKit framework linked, in memory only";
        @try {
            CharonDatabaseCases(out);
        } @catch (NSException *raised) {
            out[@"raisedDuring"] = @{@"name": raised.name ?: @"(unnamed)",
                                     @"reason": raised.reason ?: @"(no reason)"};
        }
        NSData *json = [NSJSONSerialization dataWithJSONObject:out
                                                       options:NSJSONWritingPrettyPrinted
                                                                 | NSJSONWritingSortedKeys
                                                         error:NULL];
        [json writeToFile:(path ?: @"zone-port.json") atomically:YES];
        return 0;
    }
}
