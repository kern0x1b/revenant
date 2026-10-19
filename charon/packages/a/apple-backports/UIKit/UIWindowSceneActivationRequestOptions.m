#import <UIKit/UIKit.h>

// The presentation style a new window asks for. It starts at the automatic style (0), as the release's does, and is stored as set.
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
