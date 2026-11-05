#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// The guide spans from the top of the keyboard (the bottom of the safe area while no keyboard covers the view) to
// the bottom of the view.
@interface UIKeyboardLayoutGuide ()
- (void)revenant_attachToView:(UIView *)view;
@end

@implementation UIKeyboardLayoutGuide {
    __weak UIView *_view;
    NSLayoutConstraint *_keyboardTop;
    id _observer;
}

- (void)revenant_attachToView:(UIView *)view
{
    _view = view;
    _keyboardTop = [self.topAnchor constraintEqualToAnchor:view.bottomAnchor];
    _keyboardTop.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintLessThanOrEqualToAnchor:view.safeAreaLayoutGuide.bottomAnchor],
        _keyboardTop,
        [self.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        [self.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.trailingAnchor constraintEqualToAnchor:view.trailingAnchor]]];
    __weak UIKeyboardLayoutGuide *weakSelf = self;
    _observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillChangeFrameNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        [weakSelf revenant_keyboardWillChangeFrame:notification];
    }];
}

- (void)revenant_keyboardWillChangeFrame:(NSNotification *)notification
{
    UIView *view = _view;
    UIWindow *window = view.window;
    if (!window)
        return;
    NSDictionary *info = notification.userInfo;
    CGRect frame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboard = [view convertRect:[window convertRect:frame fromWindow:nil] fromView:window];
    CGFloat overlap = MAX(0, CGRectGetMaxY(view.bounds) - MAX(CGRectGetMinY(keyboard), CGRectGetMinY(view.bounds)));
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptions)(curve << 16) | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_keyboardTop.constant = -overlap;
        [view layoutIfNeeded];
    } completion:nil];
}

- (void)dealloc
{
    if (_observer)
        [[NSNotificationCenter defaultCenter] removeObserver:_observer];
}

@end

static char revenant_keyboard_guide_key;

@implementation UIView (RevenantKeyboardLayoutGuide)

- (UIKeyboardLayoutGuide *)keyboardLayoutGuide
{
    UIKeyboardLayoutGuide *guide = objc_getAssociatedObject(self, &revenant_keyboard_guide_key);
    if (!guide) {
        guide = [[UIKeyboardLayoutGuide alloc] init];
        [self addLayoutGuide:guide];
        [guide revenant_attachToView:self];
        objc_setAssociatedObject(self, &revenant_keyboard_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return guide;
}

@end
