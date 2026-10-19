#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantWhileDraggingKey;

@implementation UITableViewCell (RevenantDragState)

- (BOOL)userInteractionEnabledWhileDragging
{
    return [objc_getAssociatedObject(self, &RevenantWhileDraggingKey) boolValue];
}

- (void)setUserInteractionEnabledWhileDragging:(BOOL)enabled
{
    objc_setAssociatedObject(self, &RevenantWhileDraggingKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dragStateDidChange:(UITableViewCellDragState)dragState
{
}

@end
