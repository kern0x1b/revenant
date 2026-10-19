#import <UIKit/UIKit.h>

// The SDK marks -init and +new unavailable: -initWithUserActivity: is the constructor. It keeps the activity object it was
// given, as the release does, and a nil activity is kept as nil. The options and the preview start nil.
@implementation UIWindowSceneActivationConfiguration {
@private
    NSUserActivity *_userActivity;
    UIWindowSceneActivationRequestOptions *_options;
    UITargetedPreview *_preview;
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

- (UIWindowSceneActivationRequestOptions *)options
{
    return _options;
}

- (void)setOptions:(UIWindowSceneActivationRequestOptions *)options
{
    _options = options;
}

- (UITargetedPreview *)preview
{
    return _preview;
}

- (void)setPreview:(UITargetedPreview *)preview
{
    _preview = preview;
}

@end
