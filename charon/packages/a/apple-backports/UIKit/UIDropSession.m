#import <UIKit/UIKit.h>

#import "CharonDragSession.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

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

- (CGPoint)locationInView:(UIView *)view
{
    UIWindow *window = view.window ?: self.interaction.view.window;
    if (!window)
        return _location;
    CGPoint inWindow = [window convertPoint:_location fromView:nil];
    return [view convertPoint:inWindow fromView:nil];
}

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
        _progress = [NSProgress progressWithTotalUnitCount:dragSession.items.count];
    }
    return self;
}

@synthesize items = _items;

- (CGPoint)locationInView:(UIView *)view
{
    return [_dragSession locationInView:view];
}

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
    return _dragSession;
}

@end
