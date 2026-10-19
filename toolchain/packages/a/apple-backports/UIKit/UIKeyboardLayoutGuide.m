#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
