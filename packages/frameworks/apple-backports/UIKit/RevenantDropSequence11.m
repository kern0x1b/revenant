#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>

#import "RevenantDragDrop.h"
#import "RevenantDragSession.h"
#import "UIDropCoordinators.h"

@interface RevenantTestDropSession : NSObject <UIDropSession>
@property (nonatomic, strong) UIDragItem *item;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, assign) UIDropSessionProgressIndicatorStyle progressIndicatorStyle;
- (instancetype)initWithPoint:(CGPoint)point;
@end

@implementation RevenantTestDropSession
@synthesize item = _item;
@synthesize point = _point;
@synthesize progress = _progress;
@synthesize progressIndicatorStyle = _progressIndicatorStyle;

- (instancetype)initWithPoint:(CGPoint)point
{
    if ((self = [super init])) {
        _point = point;
        _item = [[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:@"revenant"]];
        _progress = [NSProgress progressWithTotalUnitCount:1];
    }
    return self;
}

- (NSArray<UIDragItem *> *)items
{
    return @[_item];
}

- (CGPoint)locationInView:(UIView *)view
{
    return view ? [view convertPoint:_point fromView:nil] : _point;
}

- (BOOL)allowsMoveOperation
{
    return YES;
}

- (BOOL)isRestrictedToDraggingApplication
{
    return YES;
}

- (BOOL)hasItemsConformingToTypeIdentifiers:(NSArray<NSString *> *)typeIdentifiers
{
    return [_item.itemProvider hasItemConformingToTypeIdentifier:typeIdentifiers.firstObject];
}

- (BOOL)canLoadObjectsOfClass:(Class<NSItemProviderReading>)aClass
{
    return [_item.itemProvider canLoadObjectOfClass:aClass];
}

- (id<UIDragSession>)localDragSession
{
    return nil;
}

@end

@interface UICollectionView (RevenantDropSequence11)
- (BOOL)revenant_canHandleDropSession:(id<UIDropSession>)session;
- (void)revenant_tellDropDelegateDidEnter:(id<UIDropSession>)session;
- (UICollectionViewDropProposal *)revenant_dropProposalForSession:(id<UIDropSession>)session atIndexPath:(NSIndexPath *)destination;
- (UIDragPreviewParameters *)revenant_dropPreviewParametersForItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)revenant_performDropOfSession:(id<UIDropSession>)session;
- (void)revenant_tellDropDelegateDidExit:(id<UIDropSession>)session;
- (void)revenant_tellDropDelegateDidEnd:(id<UIDropSession>)session;
@end

@interface UITableView (RevenantDropSequence11)
- (BOOL)revenant_canHandleDropSession:(id<UIDropSession>)session;
- (void)revenant_tellDropDelegateDidEnter:(id<UIDropSession>)session;
- (UITableViewDropProposal *)revenant_dropProposalForSession:(id<UIDropSession>)session atIndexPath:(NSIndexPath *)destination;
- (UIDragPreviewParameters *)revenant_dropPreviewParametersForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)revenant_performDropOfSession:(id<UIDropSession>)session;
- (void)revenant_tellDropDelegateDidExit:(id<UIDropSession>)session;
- (void)revenant_tellDropDelegateDidEnd:(id<UIDropSession>)session;
@end

@implementation UICollectionView (RevenantDropSequence11)

- (void)revenant_driveDropSessionAtPoint:(CGPoint)point
{
    RevenantTestDropSession *session = [[RevenantTestDropSession alloc] initWithPoint:point];
    UIDropInteraction *interaction = [self revenant_dropInteraction];
    if (!interaction)
        return;
    id<UIDropInteractionDelegate> delegate = interaction.delegate;
    SEL canHandle = @selector(dropInteraction:canHandleSession:);
    if (![delegate respondsToSelector:canHandle])
        return;
    if (!((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, canHandle, interaction, session))
        return;
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidEnter:), interaction, session);
    NSIndexPath *destination = [self indexPathForItemAtPoint:[self convertPoint:point fromView:nil]];
    if (destination) {
        ((UIDropProposal * (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidUpdate:), interaction, session);
        ((UITargetedDragPreview * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, @selector(dropInteraction:previewForDroppingItem:withDefault:), interaction, session.items.firstObject, (id)[UITargetedDragPreview class]);
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:performDrop:), interaction, session);
    }
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidExit:), interaction, session);
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidEnd:), interaction, session);
}

- (UIDropInteraction *)revenant_dropInteraction
{
    for (id<UIInteraction> interaction in self.interactions)
        if ([interaction isKindOfClass:[UIDropInteraction class]])
            return (UIDropInteraction *)interaction;
    return nil;
}

@end

@implementation UITableView (RevenantDropSequence11)

- (void)revenant_driveDropSessionAtPoint:(CGPoint)point
{
    RevenantTestDropSession *session = [[RevenantTestDropSession alloc] initWithPoint:point];
    UIDropInteraction *interaction = [self revenant_dropInteraction];
    if (!interaction)
        return;
    id<UIDropInteractionDelegate> delegate = interaction.delegate;
    SEL canHandle = @selector(dropInteraction:canHandleSession:);
    if (![delegate respondsToSelector:canHandle])
        return;
    if (!((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, canHandle, interaction, session))
        return;
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidEnter:), interaction, session);
    NSIndexPath *destination = [self indexPathForRowAtPoint:[self convertPoint:point fromView:nil]];
    if (destination) {
        ((UIDropProposal * (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidUpdate:), interaction, session);
        ((UITargetedDragPreview * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, @selector(dropInteraction:previewForDroppingItem:withDefault:), interaction, session.items.firstObject, (id)[UITargetedDragPreview class]);
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:performDrop:), interaction, session);
    }
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidExit:), interaction, session);
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidEnd:), interaction, session);
}

- (UIDropInteraction *)revenant_dropInteraction
{
    for (id<UIInteraction> interaction in self.interactions)
        if ([interaction isKindOfClass:[UIDropInteraction class]])
            return (UIDropInteraction *)interaction;
    return nil;
}

@end
