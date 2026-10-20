#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_dismiss_mode_key;
static const char revenant_dismiss_tracker_key;
static CGRect revenant_keyboard_frame;
static BOOL revenant_keyboard_shown;

@interface RevenantKeyboardDismissTracker : NSObject
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, assign) BOOL dismissed;
@end

@implementation RevenantKeyboardDismissTracker
@synthesize scrollView, dismissed;

- (void)pan:(UIPanGestureRecognizer *)pan
{
    NSInteger mode = [objc_getAssociatedObject(self.scrollView, &revenant_dismiss_mode_key) integerValue];
    if (pan.state == UIGestureRecognizerStateBegan)
        self.dismissed = NO;
    if (self.dismissed || !mode || pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled)
        return;
    BOOL dismiss = NO;
    if (mode == 1) {
        dismiss = pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged;
    } else if (mode == 2 && revenant_keyboard_shown) {
        UIWindow *window = self.scrollView.window;
        CGPoint point = [pan locationInView:nil];
        CGRect keyboard = window ? [window convertRect:revenant_keyboard_frame fromWindow:nil] : revenant_keyboard_frame;
        dismiss = point.y >= CGRectGetMinY(keyboard);
    }
    if (!dismiss)
        return;
    self.dismissed = YES;
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

@end

static void revenant_observe_keyboard(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:UIKeyboardDidShowNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            revenant_keyboard_frame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
            revenant_keyboard_shown = YES;
        }];
        [center addObserverForName:UIKeyboardWillHideNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            revenant_keyboard_shown = NO;
        }];
    });
}

@implementation UIScrollView (RevenantKeyboardDismiss)

- (UIScrollViewKeyboardDismissMode)keyboardDismissMode
{
    return (UIScrollViewKeyboardDismissMode)[objc_getAssociatedObject(self, &revenant_dismiss_mode_key) integerValue];
}

- (void)setKeyboardDismissMode:(UIScrollViewKeyboardDismissMode)keyboardDismissMode
{
    objc_setAssociatedObject(self, &revenant_dismiss_mode_key, @(keyboardDismissMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!keyboardDismissMode || objc_getAssociatedObject(self, &revenant_dismiss_tracker_key))
        return;
    revenant_observe_keyboard();
    RevenantKeyboardDismissTracker *tracker = [[RevenantKeyboardDismissTracker alloc] init];
    tracker.scrollView = self;
    [self.panGestureRecognizer addTarget:tracker action:@selector(pan:)];
    objc_setAssociatedObject(self, &revenant_dismiss_tracker_key, tracker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
