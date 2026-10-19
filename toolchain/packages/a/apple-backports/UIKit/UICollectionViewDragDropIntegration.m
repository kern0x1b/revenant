#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <UIKit/UICollectionView.h>

#import "CharonDragDrop.h"
#import "CharonDragSession.h"
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UICollectionView (CharonDragDropIntegration11)
- (NSArray<UIDragInteraction *> *)charon_dragInteractions;
- (NSArray<id<UICollectionViewDropItem>> *)charon_dropItemsAtPoint:(CGPoint)point session:(id<UIDropSession>)session;
@end

@implementation UICollectionView (CharonDragDropIntegration11)

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

- (NSArray<id<UICollectionViewDropItem>> *)charon_dropItemsAtPoint:(CGPoint)point session:(id<UIDropSession>)session
{
    NSMutableArray *items = [NSMutableArray array];
    for (id<UIInteraction> interaction in self.interactions) {
        if (![interaction isKindOfClass:[UIDropInteraction class]])
            continue;
        id<UIDropInteractionDelegate> delegate = ((UIDropInteraction *)interaction).delegate;
        if (![delegate respondsToSelector:@selector(dropInteraction:sessionDidUpdate:)])
            continue;
        NSIndexPath *destination = [self indexPathForItemAtPoint:[self convertPoint:point fromView:nil]];
        if (!destination)
            continue;
        UICollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:destination];
        for (UIDragItem *item in session.items) {
            CharonCollectionDropItem *drop = [[CharonCollectionDropItem alloc] init];
            drop.item = item;
            drop.source = nil;
            drop.size = attributes ? attributes.size : CGSizeZero;
            [items addObject:drop];
        }
        return items;
    }
    return items;
}

@end
