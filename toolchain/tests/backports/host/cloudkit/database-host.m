#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdarg.h>

#import "database-cases.h"

static NSUInteger RevenantDatabaseCalls = 0;

static NSArray<NSString *> *RevenantNetworkSelectors(void)
{
    return @[@"addOperation:", @"deleteRecordWithID:completionHandler:",
             @"deleteRecordZoneWithID:completionHandler:",
             @"deleteSubscriptionWithID:completionHandler:",
             @"fetchAllRecordZonesWithCompletionHandler:",
             @"fetchAllSubscriptionsWithCompletionHandler:", @"fetchRecordWithID:completionHandler:",
             @"fetchRecordZoneWithID:completionHandler:",
             @"fetchSubscriptionWithID:completionHandler:",
             @"performQuery:inZoneWithID:completionHandler:", @"saveRecord:completionHandler:",
             @"saveRecordZone:completionHandler:", @"saveSubscription:completionHandler:"];
}

int main(void)
{
    @autoreleasepool {
        NSString *path = @(getenv("CLOUDKIT_DATABASE"));
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        out[@"conditions"] = @"in memory only: no CKDatabase operation method is called, no network,"
                             @" no account read and no state changed";
        NSString *cases = [NSString stringWithContentsOfFile:@"database-cases.m"
                                                   encoding:NSUTF8StringEncoding
                                                      error:NULL] ?: @"";
        NSMutableArray *named = [NSMutableArray array];
        for (NSString *selector in RevenantNetworkSelectors()) {
            NSString *name = [selector stringByReplacingOccurrencesOfString:@":"
                                                                  withString:@""];
            if ([cases containsString:selector] || [cases containsString:name]) {
                [named addObject:selector];
            }
        }
        if (named.count > 0) {
            out[@"refused"] = [NSString stringWithFormat:@"these cases mention %lu network operation"
                                                      @" selector(s) - %@ - so this is not an"
                                                      @" in-memory run and no answer is taken",
                                                      (unsigned long)named.count,
                                                      [named componentsJoinedByString:@", "]];
            out[@"cases"] = [NSNull null];
            out[@"databaseCalls"] = @(RevenantDatabaseCalls);
            out[@"assertion"] = @"refused: the cases name a network operation";
        } else {
            out[@"assertion"] = @"these cases mention no network operation selector, so every answer"
                                 @" below is an in-memory one";
            @try {
                RevenantDatabaseCases(out);
            } @catch (NSException *raised) {
                out[@"raisedDuring"] = @{@"name": raised.name ?: @"(unnamed)",
                                         @"reason": raised.reason ?: @"(no reason)"};
            }
        }
        NSData *json = [NSJSONSerialization dataWithJSONObject:out
                                                       options:NSJSONWritingPrettyPrinted
                                                                 | NSJSONWritingSortedKeys
                                                         error:NULL];
        [json writeToFile:(path ?: @"database-host.json") atomically:YES];
        return out[@"refused"] ? 1 : 0;
    }
}
