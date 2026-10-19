#import <BackgroundTasks/BackgroundTasks.h>

@interface BGTaskRequest (CharonBackgroundTasks)
- (instancetype)initCharonWithIdentifier:(NSString *)identifier;
@end

@interface BGTask (CharonBackgroundTasks)
- (instancetype)initCharonWithIdentifier:(NSString *)identifier;
@end
