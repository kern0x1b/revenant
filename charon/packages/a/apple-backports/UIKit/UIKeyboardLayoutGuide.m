#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// UIKeyboardLayoutGuide, iOS 15, and UIView's keyboardLayoutGuide. The guide is a tracking guide whose top is the bottom of its view's safe
// area while no keyboard is shown: measured by tests/backports/host/layout-guides, the host's frame in a window with no keyboard is the full
// width of the view, at the safe area's bottom edge, with zero height. The port does not follow the keyboard's frame, which can be read only
// on a device, so an application that expects the guide to move with a shown keyboard gets the no-keyboard position (facts/UIKit/UIKeyboardLayoutGuide.md).
// followsUndockedKeyboard is kept as set, NO by default, as the host has it.
@implementation UIKeyboardLayoutGuide {
    BOOL _followsUndockedKeyboard;
}

- (BOOL)followsUndockedKeyboard
{
    return _followsUndockedKeyboard;
}

- (void)setFollowsUndockedKeyboard:(BOOL)followsUndockedKeyboard
{
    _followsUndockedKeyboard = followsUndockedKeyboard;
}

@end

static char charon_keyboard_guide_key;

@implementation UIView (CharonKeyboardLayoutGuide)

- (UIKeyboardLayoutGuide *)keyboardLayoutGuide
{
    UIKeyboardLayoutGuide *guide = objc_getAssociatedObject(self, &charon_keyboard_guide_key);
    if (!guide) {
        guide = [[UIKeyboardLayoutGuide alloc] init];
        [self addLayoutGuide:guide];
        [NSLayoutConstraint activateConstraints:@[
            [guide.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor],
            [guide.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [guide.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [guide.heightAnchor constraintEqualToConstant:0]]];
        objc_setAssociatedObject(self, &charon_keyboard_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return guide;
}

@end
