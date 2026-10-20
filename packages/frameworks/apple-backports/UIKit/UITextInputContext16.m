#import <UIKit/UIKit.h>

@implementation UITextInputContext

- (BOOL)isPencilInputExpected
{
    return NO;
}

- (BOOL)isDictationInputExpected
{
    return NO;
}

- (BOOL)isHardwareKeyboardInputExpected
{
    return NO;
}

- (void)setPencilInputExpected:(BOOL)expected
{
}

- (void)setDictationInputExpected:(BOOL)expected
{
}

- (void)setHardwareKeyboardInputExpected:(BOOL)expected
{
}

+ (UITextInputContext *)current
{
    return [[self alloc] init];
}

@end
