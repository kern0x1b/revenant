#import <UIKit/UIKit.h>
#import "inputview-cases.h"

static NSString *view_text(UIInputView *view)
{
    return [NSString stringWithFormat:@"%@ style=%ld selfSizing=%d frame=%@ opaque=%d alpha=%.1f clips=%d background=%d", NSStringFromClass([view superclass]), (long)view.inputViewStyle, view.allowsSelfSizing, NSStringFromCGRect(view.frame), view.opaque, view.alpha, view.clipsToBounds, view.backgroundColor != nil];
}

void inputview_run(UIWindow *window, InputViewRecorder record)
{
    CGRect frame = CGRectMake(0, 0, 320, 216);
    for (NSNumber *style in @[@0, @1]) {
        UIInputView *view = [[UIInputView alloc] initWithFrame:frame inputViewStyle:(UIInputViewStyle)style.integerValue];
        record([NSString stringWithFormat:@"style.%@", style], view_text(view));
    }
    UIInputView *plain = [[UIInputView alloc] initWithFrame:frame];
    record(@"plain", view_text(plain));
    UIInputView *keyboard = [[UIInputView alloc] initWithFrame:frame inputViewStyle:UIInputViewStyleKeyboard];
    keyboard.allowsSelfSizing = YES;
    record(@"selfSizing", [NSString stringWithFormat:@"%d style=%ld", keyboard.allowsSelfSizing, (long)keyboard.inputViewStyle]);
    keyboard.allowsSelfSizing = NO;
    record(@"selfSizingCleared", [NSString stringWithFormat:@"%d", keyboard.allowsSelfSizing]);
    UIInputView *other = [[UIInputView alloc] initWithFrame:frame inputViewStyle:(UIInputViewStyle)7];
    record(@"style.7", [NSString stringWithFormat:@"%ld", (long)other.inputViewStyle]);
    UIView *child = [[UIView alloc] initWithFrame:CGRectMake(1, 2, 30, 40)];
    [keyboard addSubview:child];
    record(@"subview", [NSString stringWithFormat:@"%d %d", child.superview == keyboard, [keyboard.subviews containsObject:child]]);
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
    field.inputAccessoryView = keyboard;
    record(@"accessory", [NSString stringWithFormat:@"%d", field.inputAccessoryView == keyboard]);
    field.inputView = plain;
    record(@"inputView", [NSString stringWithFormat:@"%d", field.inputView == plain]);
    record(@"class", [NSString stringWithFormat:@"%d %d", [plain isKindOfClass:[UIView class]], [UIInputView instancesRespondToSelector:@selector(initWithFrame:inputViewStyle:)]]);
}
