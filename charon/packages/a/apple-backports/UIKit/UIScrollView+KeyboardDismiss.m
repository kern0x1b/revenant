#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_dismiss_mode_key;
static const char charon_dismiss_tracker_key;
static CGRect charon_keyboard_frame;
static BOOL charon_keyboard_shown;

@interface CharonKeyboardDismissTracker : NSObject
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, assign) BOOL dismissed;
@end

@implementation CharonKeyboardDismissTracker
@synthesize scrollView, dismissed;

- (void)pan:(UIPanGestureRecognizer *)pan
{
    NSInteger mode = [objc_getAssociatedObject(self.scrollView, &charon_dismiss_mode_key) integerValue];
    if (pan.state == UIGestureRecognizerStateBegan)
        self.dismissed = NO;
    if (self.dismissed || !mode || pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled)
        return;
    BOOL dismiss = NO;
    if (mode == 1) {
        dismiss = pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged;
    } else if (mode == 2 && charon_keyboard_shown) {
        UIWindow *window = self.scrollView.window;
        CGPoint point = [pan locationInView:nil];
        CGRect keyboard = window ? [window convertRect:charon_keyboard_frame fromWindow:nil] : charon_keyboard_frame;
        dismiss = point.y >= CGRectGetMinY(keyboard);
    }
    if (!dismiss)
        return;
    self.dismissed = YES;
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

@end

static void charon_observe_keyboard(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:UIKeyboardDidShowNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            charon_keyboard_frame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
            charon_keyboard_shown = YES;
        }];
        [center addObserverForName:UIKeyboardWillHideNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            charon_keyboard_shown = NO;
        }];
    });
}

@implementation UIScrollView (CharonKeyboardDismiss)

- (UIScrollViewKeyboardDismissMode)keyboardDismissMode
{
    return (UIScrollViewKeyboardDismissMode)[objc_getAssociatedObject(self, &charon_dismiss_mode_key) integerValue];
}

- (void)setKeyboardDismissMode:(UIScrollViewKeyboardDismissMode)keyboardDismissMode
{
    objc_setAssociatedObject(self, &charon_dismiss_mode_key, @(keyboardDismissMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!keyboardDismissMode || objc_getAssociatedObject(self, &charon_dismiss_tracker_key))
        return;
    charon_observe_keyboard();
    CharonKeyboardDismissTracker *tracker = [[CharonKeyboardDismissTracker alloc] init];
    tracker.scrollView = self;
    [self.panGestureRecognizer addTarget:tracker action:@selector(pan:)];
    objc_setAssociatedObject(self, &charon_dismiss_tracker_key, tracker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
