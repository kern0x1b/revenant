#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UIResponder (RevenantTextInput7)

- (UITextInputMode *)textInputMode
{
    return [UITextInputMode currentInputMode];
}

- (NSString *)textInputContextIdentifier
{
    return nil;
}

+ (void)clearTextInputContextIdentifier:(NSString *)identifier
{
}

@end
