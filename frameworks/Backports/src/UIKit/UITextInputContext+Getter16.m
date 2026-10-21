#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UITextInputContext (RevenantGetter16)

- (BOOL)dictationInputExpected
{
    return [self isDictationInputExpected];
}

- (BOOL)hardwareKeyboardInputExpected
{
    return [self isHardwareKeyboardInputExpected];
}

- (BOOL)pencilInputExpected
{
    return [self isPencilInputExpected];
}

@end
