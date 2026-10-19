#import <UIKit/UIKit.h>

@implementation UIResponder (CharonTargetForAction)

- (id)targetForAction:(SEL)action withSender:(id)sender
{
    if ([self canPerformAction:action withSender:sender])
        return self;
    return [[self nextResponder] targetForAction:action withSender:sender];
}

@end
