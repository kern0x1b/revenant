#import <UIKit/UIKit.h>
#import "CharonMenus.h"

@implementation UIControl (CharonPerformPrimaryAction17)

- (void)performPrimaryAction
{
    [self sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
}

@end
