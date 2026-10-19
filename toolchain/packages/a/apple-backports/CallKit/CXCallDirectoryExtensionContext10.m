#import <CallKit/CallKit.h>

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
