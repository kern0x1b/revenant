#import <SafariServices/SafariServices.h>

@interface SFSafariViewControllerPrewarmingToken ()
- (instancetype)revenant_init;
@end

@implementation SFSafariViewControllerPrewarmingToken

- (instancetype)init
{
    [NSException raise:NSGenericException format:@"Misuse of SFSafariViewControllerPrewarmingToken interface."];
    return nil;
}

- (instancetype)revenant_init
{
    return [super init];
}

- (void)invalidate
{
}

@end

SFSafariViewControllerPrewarmingToken *revenant_prewarmingToken(void)
{
    return [[SFSafariViewControllerPrewarmingToken alloc] revenant_init];
}
