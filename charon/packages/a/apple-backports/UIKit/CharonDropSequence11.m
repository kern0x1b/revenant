#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>

#import "CharonDragDrop.h"
#import "CharonDragSession.h"
#import "UIDropCoordinators.h"

// One drop, run through, in one place so the routing and the test that asserts it read the same
// order. The messages are the ones ViewDragDropRouting11.m asks; this only says which comes next,
// and it is a separate object rather than a method in that file so the sequence is one readable list
// and the mutation that must turn the test red is a swap of two lines in it.
//
// The order is the host's own, or where the host cannot be asked: the iOSSupport UIKit is the macOS
// UIKit and the four drag and drop delegate protocols are iOS-only, so a conforming Catalyst probe
// does not compile. The sequence is the documented one, and the one ordering an upstream does show
// is WinObjC (MIT) at 94f6b5bf, UICollectionView.mm:1730-1750 -- remove, then tell, then reuse.

@interface CharonTestDropSession : NSObject <UIDropSession>
@property (nonatomic, strong) UIDragItem *item;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, assign) UIDropSessionProgressIndicatorStyle progressIndicatorStyle;
- (instancetype)initWithPoint:(CGPoint)point;
@end

@implementation CharonTestDropSession
@synthesize item = _item;
@synthesize point = _point;
@synthesize progress = _progress;
@synthesize progressIndicatorStyle = _progressIndicatorStyle;

// One item carrying a provider, so a delegate that asks what the session carries gets an answer and
// the coordinator has something to move.
- (instancetype)initWithPoint:(CGPoint)point
{
    if ((self = [super init])) {
        _point = point;
        _item = [[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:@"charon"]];
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

@interface UICollectionView (CharonDropSequence11)
- (BOOL)charon_canHandleDropSession:(id<UIDropSession>)session;
- (void)charon_tellDropDelegateDidEnter:(id<UIDropSession>)session;
- (UICollectionViewDropProposal *)charon_dropProposalForSession:(id<UIDropSession>)session atIndexPath:(NSIndexPath *)destination;
- (UIDragPreviewParameters *)charon_dropPreviewParametersForItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)charon_performDropOfSession:(id<UIDropSession>)session;
- (void)charon_tellDropDelegateDidExit:(id<UIDropSession>)session;
- (void)charon_tellDropDelegateDidEnd:(id<UIDropSession>)session;
@end

@interface UITableView (CharonDropSequence11)
- (BOOL)charon_canHandleDropSession:(id<UIDropSession>)session;
- (void)charon_tellDropDelegateDidEnter:(id<UIDropSession>)session;
- (UITableViewDropProposal *)charon_dropProposalForSession:(id<UIDropSession>)session atIndexPath:(NSIndexPath *)destination;
- (UIDragPreviewParameters *)charon_dropPreviewParametersForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)charon_performDropOfSession:(id<UIDropSession>)session;
- (void)charon_tellDropDelegateDidExit:(id<UIDropSession>)session;
- (void)charon_tellDropDelegateDidEnd:(id<UIDropSession>)session;
@end

@implementation UICollectionView (CharonDropSequence11)

// One drop over this view: the interaction over it is asked, in the order the header gives, and the
// interaction is what calls its delegate. The sequence lives here rather than in the interaction so
// that a view's own routing and the interaction's are two things that can both be wrong, and so the
// order is one list a test can be written against.
- (void)charon_driveDropSessionAtPoint:(CGPoint)point
{
    CharonTestDropSession *session = [[CharonTestDropSession alloc] initWithPoint:point];
    UIDropInteraction *interaction = [self charon_dropInteraction];
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

// The drop interaction over this view, which is the one whose delegate the sequence asks.
- (UIDropInteraction *)charon_dropInteraction
{
    for (id<UIInteraction> interaction in self.interactions)
        if ([interaction isKindOfClass:[UIDropInteraction class]])
            return (UIDropInteraction *)interaction;
    return nil;
}

@end

@implementation UITableView (CharonDropSequence11)

// One drop over a table, the same order and through the same interaction's delegate.
- (void)charon_driveDropSessionAtPoint:(CGPoint)point
{
    CharonTestDropSession *session = [[CharonTestDropSession alloc] initWithPoint:point];
    UIDropInteraction *interaction = [self charon_dropInteraction];
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

- (UIDropInteraction *)charon_dropInteraction
{
    for (id<UIInteraction> interaction in self.interactions)
        if ([interaction isKindOfClass:[UIDropInteraction class]])
            return (UIDropInteraction *)interaction;
    return nil;
}

@end
