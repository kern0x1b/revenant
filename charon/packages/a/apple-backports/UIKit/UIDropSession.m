#import <UIKit/UIKit.h>

#import "CharonDragSession.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// A drag, from the long press that lifts it to the drop that ends it.
//
// The gestures are the release's own: a long press lifts and a pan carries, which is what makes a
// drag a drag rather than a swipe. Lifting asks the delegate what is being dragged and builds the
// preview from the view under the touch; carrying moves that preview; letting go finds the drop
// interaction under the point, asks its delegate what it makes of the session, and hands the items
// over. The data itself is the item provider's, and the provider is what moves it — nothing here
// copies a payload.
//
// A drag that would leave the application is not offered. This release has no service to carry one,
// so a session is restricted to the application that started it, which is what a device of this era
// answers, and the delegate is asked about it so an application can see the answer rather than have
// it assumed.

@class CharonDragSession;

@implementation CharonDragSession
@synthesize items = _items;
@synthesize localContext = _localContext;
@synthesize location = _location;
@synthesize interaction = _interaction;
@synthesize allowsMoveOperation = _allowsMoveOperation;

- (instancetype)initWithItems:(NSArray<UIDragItem *> *)items interaction:(UIDragInteraction *)interaction
{
    if ((self = [super init])) {
        _items = [items mutableCopy] ?: [NSMutableArray array];
        _interaction = interaction;
        _allowsMoveOperation = YES;
    }
    return self;
}

// Where the drag is, in whichever view is asked: the point is kept in the window's space and
// converted into the view's, so a delegate can ask about the point in its own coordinate space.
- (CGPoint)locationInView:(UIView *)view
{
    UIWindow *window = view.window ?: self.interaction.view.window;
    if (!window)
        return _location;
    CGPoint inWindow = [window convertPoint:_location fromView:nil];
    return [view convertPoint:inWindow fromView:nil];
}

// A drag on this release stays inside the application that began it, so a move is allowed and
// nothing else is: there is no service to carry it out of here.
- (BOOL)isRestrictedToDraggingApplication
{
    return YES;
}

- (BOOL)hasItemsConformingToTypeIdentifiers:(NSArray<NSString *> *)typeIdentifiers
{
    for (UIDragItem *item in _items)
        if ([item.itemProvider hasItemConformingToTypeIdentifier:typeIdentifiers.firstObject])
            return YES;
    return NO;
}

- (BOOL)canLoadObjectsOfClass:(Class<NSItemProviderReading>)aClass
{
    for (UIDragItem *item in _items)
        if ([item.itemProvider canLoadObjectOfClass:aClass])
            return YES;
    return NO;
}

@end

@implementation CharonDropSession
@synthesize progress = _progress;
@synthesize progressIndicatorStyle = _progressIndicatorStyle;
@synthesize dragSession = _dragSession;
@synthesize interaction = _interaction;

- (instancetype)initWithDragSession:(CharonDragSession *)dragSession interaction:(UIDropInteraction *)interaction
{
    if ((self = [super init])) {
        _dragSession = dragSession;
        _items = dragSession.items;
        _interaction = interaction;
        // A progress with one unit per item, which is what a drop of a handful of items measures.
        _progress = [NSProgress progressWithTotalUnitCount:dragSession.items.count];
    }
    return self;
}

// The items of the drag session, held here as well so a drop answers for what it was given even if
// the drag session is gone by the time the delegate is asked.
@synthesize items = _items;

- (CGPoint)locationInView:(UIView *)view
{
    return [_dragSession locationInView:view];
}

// The data of the dropped items, loaded through the provider that carries it: this is the whole of
// what a drop moves, and it is the provider's own loading, not a copy made here.
- (NSProgress *)loadObjectsOfClass:(Class<NSItemProviderReading>)aClass completion:(void (^)(NSArray<__kindof id<NSItemProviderReading>> *objects))completion
{
    NSMutableArray *loaded = [NSMutableArray array];
    for (UIDragItem *item in _dragSession.items)
        [item.itemProvider loadObjectOfClass:aClass completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            if (object)
                [loaded addObject:object];
        }];
    self.progress.completedUnitCount = self.progress.totalUnitCount;
    if (completion)
        completion(loaded);
    return self.progress;
}

- (BOOL)isRestrictedToDraggingApplication
{
    return YES;
}

- (BOOL)hasItemsConformingToTypeIdentifiers:(NSArray<NSString *> *)typeIdentifiers
{
    return [_dragSession hasItemsConformingToTypeIdentifiers:typeIdentifiers];
}

- (BOOL)allowsMoveOperation
{
    return _dragSession.allowsMoveOperation;
}

- (BOOL)canLoadObjectsOfClass:(Class<NSItemProviderReading>)aClass
{
    return [_dragSession canLoadObjectsOfClass:aClass];
}

- (id<UIDragSession>)localDragSession
{
    // A drop inside the application is always the local session: there is no other one to be had.
    return _dragSession;
}

@end
