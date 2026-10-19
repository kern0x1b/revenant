#import <UIKit/UIKit.h>

#import "CharonDragDrop.h"
#import "CharonDragSession.h"
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UITableView (CharonDragDropIntegration11)
- (NSArray<UIDragInteraction *> *)charon_dragInteractions;
- (NSArray<id<UITableViewDropItem>> *)charon_dropItemsAtPoint:(CGPoint)point session:(id<UIDropSession>)session;
@end

@implementation UITableView (CharonDragDropIntegration11)

- (NSArray<UIDragInteraction *> *)charon_dragInteractions
{
    NSMutableArray *found = [NSMutableArray array];
    for (id<UIInteraction> interaction in self.interactions)
        if ([interaction isKindOfClass:[UIDragInteraction class]])
            [found addObject:(UIDragInteraction *)interaction];
    return found;
}

- (BOOL)hasActiveDrag
{
    for (UIDragInteraction *drag in [self charon_dragInteractions])
        if (drag.session)
            return YES;
    return NO;
}

- (BOOL)hasActiveDrop
{
    for (id<UIInteraction> interaction in self.interactions) {
        if (![interaction isKindOfClass:[UIDropInteraction class]])
            continue;
        if (((UIDropInteraction *)interaction).currentDrop)
            return YES;
    }
    return NO;
}

- (NSArray<id<UITableViewDropItem>> *)charon_dropItemsAtPoint:(CGPoint)point session:(id<UIDropSession>)session
{
    NSMutableArray *items = [NSMutableArray array];
    for (id<UIInteraction> interaction in self.interactions) {
        if (![interaction isKindOfClass:[UIDropInteraction class]])
            continue;
        id<UIDropInteractionDelegate> delegate = ((UIDropInteraction *)interaction).delegate;
        if (![delegate respondsToSelector:@selector(dropInteraction:sessionDidUpdate:)])
            continue;
        NSIndexPath *destination = [self indexPathForRowAtPoint:[self convertPoint:point fromView:nil]];
        if (!destination)
            continue;
        for (UIDragItem *item in session.items) {
            CharonTableDropItem *drop = [[CharonTableDropItem alloc] init];
            drop.item = item;
            drop.source = [self indexPathForRowAtPoint:CGPointZero];
            drop.size = CGSizeMake(self.bounds.size.width, self.rowHeight);
            [items addObject:drop];
        }
        return items;
    }
    return items;
}

@end
