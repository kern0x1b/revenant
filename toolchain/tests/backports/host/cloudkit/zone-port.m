#import <Foundation/Foundation.h>

#import "database-cases.h"

int main(void)
{
    @autoreleasepool {
        NSString *path = @(getenv("CLOUDKIT_ZONE"));
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        out[@"conditions"] = @"the port's own objects, no CloudKit framework linked, in memory only";
        @try {
            RevenantDatabaseCases(out);
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
