#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "RevenantKeyboardSwitch.h"

static const NSTimeInterval RevenantKeyboardSwitchWait = 0.15;

@interface RevenantKeyboardInputSwitch : NSObject
@end

@implementation RevenantKeyboardInputSwitch

static RevenantKeyboardSwitch revenant_switch_state;
static BOOL revenant_switch_posting;

+ (void)load
{
    RevenantKeyboardSwitchInit(&revenant_switch_state);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    for (NSString *name in @[UIKeyboardWillChangeFrameNotification, UIKeyboardWillShowNotification, UIKeyboardWillHideNotification]) {
        [center addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
            if (revenant_switch_posting)
                return;
            RevenantKeyboardSwitchNotice(&revenant_switch_state, [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue], [UIScreen mainScreen].bounds, CACurrentMediaTime());
        }];
    }
    void (^began)(NSNotification *) = ^(NSNotification *note) {
        if (![NSThread isMainThread] || ![note.object conformsToProtocol:@protocol(UITextInputTraits)])
            return;
        if (!RevenantKeyboardSwitchBegan(&revenant_switch_state, (long)[(id<UITextInputTraits>)note.object keyboardType]))
            return;
        double since = CACurrentMediaTime();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RevenantKeyboardSwitchWait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (RevenantKeyboardSwitchDue(&revenant_switch_state, since))
                [self announce];
        });
    };
    [center addObserverForName:UITextFieldTextDidBeginEditingNotification object:nil queue:nil usingBlock:began];
    [center addObserverForName:UITextViewTextDidBeginEditingNotification object:nil queue:nil usingBlock:began];
}

+ (void)announce
{
    CGRect shown = revenant_switch_state.shown;
    CGRect hidden = RevenantKeyboardSwitchHidden(shown);
    NSDictionary *(^info)(CGRect, CGRect) = ^NSDictionary *(CGRect from, CGRect to) {
        return @{UIKeyboardFrameBeginUserInfoKey: [NSValue valueWithCGRect:from], UIKeyboardFrameEndUserInfoKey: [NSValue valueWithCGRect:to],
                 UIKeyboardAnimationDurationUserInfoKey: @0.25, UIKeyboardAnimationCurveUserInfoKey: @(UIViewAnimationCurveEaseInOut),
                 UIKeyboardIsLocalUserInfoKey: @YES};
    };
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    UIScreen *screen = [UIScreen mainScreen];
    revenant_switch_posting = YES;
    @try {
        [center postNotificationName:UIKeyboardWillChangeFrameNotification object:screen userInfo:info(shown, hidden)];
        for (UIWindow *window in [[UIApplication sharedApplication] windows])
            [window layoutIfNeeded];
        [center postNotificationName:UIKeyboardWillChangeFrameNotification object:screen userInfo:info(hidden, shown)];
    } @finally {
        revenant_switch_posting = NO;
    }
}

@end
