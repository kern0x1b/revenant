#import "RevenantKeyInputView.h"

@implementation RevenantKeyInputView {
    UIKeyboardType _kbType;
    BOOL _secure;
}

@synthesize consumer = _consumer;

- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)hasText { return YES; }

- (void)configureForType:(NSString *)inputType
{
    _secure = [inputType isEqualToString:@"password"];
    _kbType = [inputType isEqualToString:@"email"] ? UIKeyboardTypeEmailAddress
            : ([inputType isEqualToString:@"tel"] ? UIKeyboardTypePhonePad
            : ([inputType isEqualToString:@"number"] ? UIKeyboardTypeNumberPad : UIKeyboardTypeDefault));
}

- (void)insertText:(NSString *)text
{
    if ([text isEqualToString:@"\n"]) {
        [_consumer typeReturn];
        return;
    }
    [_consumer typeCharacters:text];
}

- (void)deleteBackward { [_consumer typeBackspace]; }
- (UIKeyboardType)keyboardType { return _kbType; }
- (void)setKeyboardType:(UIKeyboardType)t { _kbType = t; }
- (BOOL)isSecureTextEntry { return _secure; }
- (void)setSecureTextEntry:(BOOL)s { _secure = s; }
- (UITextAutocapitalizationType)autocapitalizationType { return UITextAutocapitalizationTypeNone; }
- (UITextAutocorrectionType)autocorrectionType { return UITextAutocorrectionTypeNo; }

@end
