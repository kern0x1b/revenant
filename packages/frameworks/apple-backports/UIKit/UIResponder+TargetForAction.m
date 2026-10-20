#import <UIKit/UIKit.h>

@implementation UIResponder (RevenantTargetForAction)

- (id)targetForAction:(SEL)action withSender:(id)sender
{
    if ([self canPerformAction:action withSender:sender])
        return self;
    return [[self nextResponder] targetForAction:action withSender:sender];
}

@end
