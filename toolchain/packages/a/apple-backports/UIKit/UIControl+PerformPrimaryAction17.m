#import <UIKit/UIKit.h>
#import "RevenantMenus.h"

@implementation UIControl (RevenantPerformPrimaryAction17)

- (void)performPrimaryAction
{
    [self sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
}

@end
