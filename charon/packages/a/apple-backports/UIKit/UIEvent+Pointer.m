#import <UIKit/UIKit.h>

UIEventButtonMask UIEventButtonMaskForButtonNumber(NSInteger buttonNumber)
{
    if (buttonNumber < 0 || buttonNumber - 1 > (NSInteger)(sizeof(NSInteger) * 8) - 3)
        return 0;
    return (UIEventButtonMask)((NSInteger)1 << (buttonNumber > 1 ? buttonNumber - 1 : 0));
}

@implementation UIEvent (CharonPointer)

- (UIKeyModifierFlags)modifierFlags
{
    return 0;
}

- (UIEventButtonMask)buttonMask
{
    return 0;
}

@end
