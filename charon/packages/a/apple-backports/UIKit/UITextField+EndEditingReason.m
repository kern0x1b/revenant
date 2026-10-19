#import <UIKit/UIKit.h>

@interface CharonEndEditingReason : NSObject
@end

@implementation CharonEndEditingReason

+ (void)load
{
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0)
        return;
    [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidEndEditingNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
        UITextField *field = notification.object;
        id<UITextFieldDelegate> delegate = field.delegate;
        if ([delegate respondsToSelector:@selector(textFieldDidEndEditing:reason:)] && ![delegate respondsToSelector:@selector(textFieldDidEndEditing:)])
            [delegate textFieldDidEndEditing:field reason:UITextFieldDidEndEditingReasonCommitted];
    }];
}

@end
