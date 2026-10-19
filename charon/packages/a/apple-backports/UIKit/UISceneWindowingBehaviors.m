#import <UIKit/UIKit.h>

// UISceneWindowingBehaviors, iOS 16. The traffic-light controls of a window's scene, which the host's Mac Catalyst scene vends and the port's
// scene never does: UIWindowScene's windowingBehaviors is nil on iPhone and iPad, as the header says (UIWindowScene+Windowing16.m). The class
// is carried so an application that links it launches. Measured on the host (tests/backports/host/window-scene-geometry), a made object answers
// NO for both flags, and a set changes neither, so the flags here are fixed at NO and a set does nothing.
@implementation UISceneWindowingBehaviors

- (BOOL)isClosable
{
    return NO;
}

- (void)setClosable:(BOOL)closable
{
}

- (BOOL)isMiniaturizable
{
    return NO;
}

- (void)setMiniaturizable:(BOOL)miniaturizable
{
}

@end
