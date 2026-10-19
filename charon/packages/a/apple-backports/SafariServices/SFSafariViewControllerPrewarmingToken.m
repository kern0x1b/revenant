#import <SafariServices/SafariServices.h>

@interface SFSafariViewControllerPrewarmingToken ()
- (instancetype)charon_init;
@end

@implementation SFSafariViewControllerPrewarmingToken

- (instancetype)init
{
    [NSException raise:NSGenericException format:@"Misuse of SFSafariViewControllerPrewarmingToken interface."];
    return nil;
}

- (instancetype)charon_init
{
    return [super init];
}

- (void)invalidate
{
}

@end

SFSafariViewControllerPrewarmingToken *charon_prewarmingToken(void)
{
    return [[SFSafariViewControllerPrewarmingToken alloc] charon_init];
}
