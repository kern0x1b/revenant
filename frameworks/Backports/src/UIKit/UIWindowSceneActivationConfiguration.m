#import <UIKit/UIKit.h>

@implementation UIWindowSceneActivationConfiguration {
@private
    NSUserActivity *_userActivity;
}

- (instancetype)initWithUserActivity:(NSUserActivity *)userActivity
{
    if ((self = [super init])) {
        _userActivity = userActivity;
    }
    return self;
}

- (NSUserActivity *)userActivity
{
    return _userActivity;
}

@end
