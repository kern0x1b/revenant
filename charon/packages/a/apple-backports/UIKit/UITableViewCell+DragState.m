#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonWhileDraggingKey;

@implementation UITableViewCell (CharonDragState)

- (BOOL)userInteractionEnabledWhileDragging
{
    return [objc_getAssociatedObject(self, &CharonWhileDraggingKey) boolValue];
}

- (void)setUserInteractionEnabledWhileDragging:(BOOL)enabled
{
    objc_setAssociatedObject(self, &CharonWhileDraggingKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dragStateDidChange:(UITableViewCellDragState)dragState
{
}

@end
