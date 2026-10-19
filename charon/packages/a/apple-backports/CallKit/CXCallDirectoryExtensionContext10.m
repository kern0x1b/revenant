#import <CallKit/CallKit.h>

// The context the system hands a call directory extension, which iOS 6 never runs: a context the application makes
// has no host, so the entries go nowhere and completing the request is never answered, as with the host's
// CXCallDirectoryExtensionContext that has none.
// A context that is not incremental takes no removals: the host raises this, with this text, for each of the four.
static void charon_refuse_removal(SEL selector)
{
    [NSException raise:NSInternalInconsistencyException format:@"Calling %@ when isIncremental is false is unsupported", NSStringFromSelector(selector)];
}

@implementation CXCallDirectoryExtensionContext

@synthesize delegate;

- (BOOL)isIncremental
{
    return NO;
}

- (void)addBlockingEntryWithNextSequentialPhoneNumber:(CXCallDirectoryPhoneNumber)phoneNumber
{
}

- (void)removeBlockingEntryWithPhoneNumber:(CXCallDirectoryPhoneNumber)phoneNumber
{
    charon_refuse_removal(_cmd);
}

- (void)removeAllBlockingEntries
{
    charon_refuse_removal(_cmd);
}

- (void)addIdentificationEntryWithNextSequentialPhoneNumber:(CXCallDirectoryPhoneNumber)phoneNumber label:(NSString *)label
{
}

- (void)removeIdentificationEntryWithPhoneNumber:(CXCallDirectoryPhoneNumber)phoneNumber
{
    charon_refuse_removal(_cmd);
}

- (void)removeAllIdentificationEntries
{
    charon_refuse_removal(_cmd);
}

- (void)completeRequestWithCompletionHandler:(void (^)(BOOL expired))completion
{
}

@end
