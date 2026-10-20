#import <BackgroundTasks/BackgroundTasks.h>

@interface BGTaskRequest (RevenantBackgroundTasks)
- (instancetype)initRevenantWithIdentifier:(NSString *)identifier;
@end

@interface BGTask (RevenantBackgroundTasks)
- (instancetype)initRevenantWithIdentifier:(NSString *)identifier;
@end
