#import <BackgroundTasks/BackgroundTasks.h>
#import "RevenantBackgroundTasks.h"

@implementation BGTask {
    NSString *_identifier;
    void (^_expirationHandler)(void);
}

- (instancetype)initRevenantWithIdentifier:(NSString *)identifier
{
    if ((self = [super init]))
        _identifier = [identifier copy];
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (void (^)(void))expirationHandler
{
    return _expirationHandler;
}

- (void)setExpirationHandler:(void (^)(void))expirationHandler
{
    _expirationHandler = [expirationHandler copy];
}

- (void)setTaskCompletedWithSuccess:(BOOL)success
{
    _expirationHandler = nil;
}

@end

@implementation BGAppRefreshTask
@end

@implementation BGProcessingTask
@end
