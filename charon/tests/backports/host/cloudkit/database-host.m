// The host's own iOS CloudKit, asked the database cases and printing the answers as JSON.
//
// Built as a Mac Catalyst binary against the iOSSupport frameworks in the macOS SDK, so what answers
// is the host's *iOS* CloudKit and not the macOS one - a macOS build would answer a different
// framework's behaviour, and the whole point is to compare against an iOS port.
//
// No CloudKit header is imported here. database-cases.h declares the surface, and the runtime supplies
// the classes, which is the same arrangement the record half uses and the reason the two builds can
// run one set of cases: the port's build links nothing at all and gets the same names from
// packages/a/apple-backports/CloudKit.
//
// IN MEMORY ONLY, AND THE RUN PROVES IT. No CloudKit header is imported, no socket is opened, no
// account is read and no state is changed: the cases build values and read them back. Two, and the answers are written into the output
// beside the cases so a reader can see which they hold under:
//
// What the cases measure is everything a database says about ITSELF - its container identifier, its
// scope, and what its own initializers do - and nothing that reaches the network. The members that do
// reach it are owed, and the facts file says why.
//
//     xcrun clang -target arm64-apple-ios13.1-macabi \
//         -isysroot "$(xcrun --show-sdk-path --sdk macosx)" \
//         -framework Foundation -framework CloudKit \
//         -o database-host database-host.m database-cases.m
//     CLOUDKIT_DATABASE=host.json ./database-host
//
// No sandbox and no network toggle: an in-memory run does not need a denial, and the run checks
// itself instead (CharonDatabaseCalls, below).

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdarg.h>

#import "database-cases.h"

/// The assertion that makes this an in-memory run: NO CKDatabase operation method is reached.
///
/// The cases below read values, build values and let a refused initializer raise. Nothing here calls
/// fetch, save, delete, modify, addOperation: or anything else that would reach Apple's servers - and
/// "nothing here calls" is a claim about the cases, so it is checked rather than asserted in a
/// comment: CharonCloudKitCallsInto(swizzled) counts every CKDatabase selector the runtime dispatches
/// while the cases run, and the run REFUSES its own answers if the count is not zero. A case that grew
/// a fetch by accident would then fail the run instead of quietly reaching the network on a machine
/// that has an iCloud account signed in.
static NSUInteger CharonDatabaseCalls = 0;

/// The network operations of CKDatabase, by selector, listed from the ledger rather than from memory:
/// every -[CKDatabase ...] row that reaches the network, and nothing that only reads. The static
/// assertion below matches the cases file against this list, so the list is the rule and not a summary
/// of it - a case that grows a fetch the ledger knows about is caught by construction.
static NSArray<NSString *> *CharonNetworkSelectors(void)
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
        // the account is not consulted and nothing is signed out: an in-memory run does not need to
        // know, and the owner's iCloud state is not this program's to read or change
        out[@"conditions"] = @"in memory only: no CKDatabase operation method is called, no network,"
                             @" no account read and no state changed";
        // THE STATIC ASSERTION, and it is what the runtime count could not be. A Catalyst binary on
        // this host is KILLED (exit 133, no output) the moment it swizzles a method of a system
        // framework, so counting calls at runtime is not available here - but the thing that matters is
        // not how many times a case called a network operation, it is that these cases cannot call one
        // at all. That is decided by the cases file, so it is read: if it mentions any network
        // operation selector, the run refuses its own answers. One grep, and it cannot be fooled by a
        // case that grows a fetch later.
        NSString *cases = [NSString stringWithContentsOfFile:@"database-cases.m"
                                                   encoding:NSUTF8StringEncoding
                                                      error:NULL] ?: @"";
        NSMutableArray *named = [NSMutableArray array];
        for (NSString *selector in CharonNetworkSelectors()) {
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
            out[@"databaseCalls"] = @(CharonDatabaseCalls);
            out[@"assertion"] = @"refused: the cases name a network operation";
        } else {
            out[@"assertion"] = @"these cases mention no network operation selector, so every answer"
                                 @" below is an in-memory one";
            // A case that raises is an ANSWER, not a crash: CloudKit refuses -init and refuses a
            // default zone in ways a caller has to hold to, so an exception is caught here and named,
            // and the run carries on. Without this the process aborts on the first refusal and every
            // case after it is lost, which is how a refusal hides the answers that came before it.
            @try {
                CharonDatabaseCases(out);
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
