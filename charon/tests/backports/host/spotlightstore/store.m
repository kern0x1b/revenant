// Holds CSSearchableIndex.m's file store to what its completion handlers answer: a write that fails
// hands back CSIndexErrorCodeIndexUnavailableError with the Foundation cause under
// NSUnderlyingErrorKey, and leaves nothing of the failed call in memory - neither for
// -fetchLastClientState nor for the next save that succeeds. run.sh builds the port's own
// CoreSpotlight sources with the store root moved into its build directory and takes the write
// permission away from the store's directory for the first half.
#import <CoreSpotlight/CoreSpotlight.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

static int failures;

static void check(BOOL condition, NSString *what)
{
    printf("%s %s\n", condition ? "ok" : "FAIL", what.UTF8String);
    if (!condition)
        failures++;
}

static NSError *answerOf(void (^call)(void (^)(NSError *)))
{
    __block NSError *answer = (NSError *)[NSNull null];
    call(^(NSError *error) { answer = error; });
    return answer;
}

static CSSearchableItem *item(NSString *identifier)
{
    CSSearchableItemAttributeSet *attributes = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"public.text"];
    attributes.title = identifier;
    return [[CSSearchableItem alloc] initWithUniqueIdentifier:identifier domainIdentifier:@"d" attributeSet:attributes];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *storeFile = [NSString stringWithUTF8String:argv[1]];
        NSString *directory = storeFile.stringByDeletingLastPathComponent;
        CSSearchableIndex *index = [[CSSearchableIndex alloc] initWithName:@"store"];

        NSError *error = answerOf(^(void (^done)(NSError *)) { [index indexSearchableItems:@[item(@"refused")] completionHandler:done]; });
        check([error.domain isEqualToString:CSIndexErrorDomain] && error.code == CSIndexErrorCodeIndexUnavailableError,
              [NSString stringWithFormat:@"a refused write answers CSIndexErrorCodeIndexUnavailableError (%@)", error]);
        NSError *cause = error.userInfo[NSUnderlyingErrorKey];
        check([cause.domain isEqualToString:NSCocoaErrorDomain] && cause.code == NSFileWriteNoPermissionError,
              [NSString stringWithFormat:@"its cause is the refused write, under NSUnderlyingErrorKey (%@)", cause]);
        check([error.localizedDescription rangeOfString:storeFile].location != NSNotFound, @"its description names the store's file");

        NSData *state = [@"refused" dataUsingEncoding:NSUTF8StringEncoding];
        error = answerOf(^(void (^done)(NSError *)) { [index endIndexBatchWithClientState:state completionHandler:done]; });
        check(error.code == CSIndexErrorCodeIndexUnavailableError, @"a refused client state answers the error");
        __block NSData *fetched = (NSData *)[NSNull null];
        [index fetchLastClientStateWithCompletionHandler:^(NSData *answer, NSError *fetchError) { fetched = answer; }];
        check(fetched == nil, [NSString stringWithFormat:@"the refused client state is not answered afterwards (%@)", fetched]);

        chmod(directory.fileSystemRepresentation, 0755);
        error = answerOf(^(void (^done)(NSError *)) { [index indexSearchableItems:@[item(@"stored")] completionHandler:done]; });
        check(error == nil, [NSString stringWithFormat:@"a write that is allowed answers nil (%@)", error]);
        NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:storeFile];
        check([[disk[@"entries"] allKeys] isEqualToArray:@[@"stored"]],
              [NSString stringWithFormat:@"the next save writes only what was stored, not the refused item (%@)", [disk[@"entries"] allKeys]]);
        check(disk[@"clientState"] == nil, @"the next save writes no refused client state");
    }
    printf("failures: %d\n", failures);
    return failures ? 1 : 0;
}
