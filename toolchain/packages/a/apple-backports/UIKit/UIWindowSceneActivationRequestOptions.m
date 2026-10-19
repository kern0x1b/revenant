#import <UIKit/UIKit.h>

@implementation UIWindowSceneActivationRequestOptions {
@private
    UIWindowScenePresentationStyle _preferredPresentationStyle;
}

- (UIWindowScenePresentationStyle)preferredPresentationStyle
{
    return _preferredPresentationStyle;
}

- (void)setPreferredPresentationStyle:(UIWindowScenePresentationStyle)preferredPresentationStyle
{
    _preferredPresentationStyle = preferredPresentationStyle;
}

@end
