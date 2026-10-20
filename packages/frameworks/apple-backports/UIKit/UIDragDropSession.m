#import <UIKit/UIKit.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>

#import "UIDropCoordinators.h"

@interface UIDragDropSession : NSObject <UIDropSession>
@property (nonatomic, strong) NSArray<UIDragItem *> *items;
@property (nonatomic, assign) CGPoint location;
@property (nonatomic, weak) UIView *owner;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, assign) UIDropSessionProgressIndicatorStyle progressIndicatorStyle;
@property (nonatomic, strong, nullable) id<UIDragSession> localDragSession;
@end

@implementation UIDragDropSession
@synthesize items = _items;
@synthesize location = _location;
@synthesize owner = _owner;
@synthesize progress = _progress;
@synthesize progressIndicatorStyle = _progressIndicatorStyle;
@synthesize localDragSession = _localDragSession;

- (instancetype)init
{
    return [self initWithItems:@[]];
}

- (instancetype)initWithItems:(NSArray<UIDragItem *> *)items
{
    if ((self = [super init])) {
        _items = items ?: @[];
        _progress = [NSProgress progressWithTotalUnitCount:_items.count];
        _localDragSession = nil;
    }
    return self;
}

- (CGPoint)locationInView:(UIView *)view
{
    if (!view)
        return _location;
    return [view convertPoint:_location fromView:nil];
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

- (NSProgress *)loadObjectsOfClass:(Class<NSItemProviderReading>)aClass
                        completion:(void (^)(NSArray<__kindof id<NSItemProviderReading>> *objects))completion
{
    NSProgress *progress = self.progress;
    [progress cancel];
    progress.totalUnitCount = _items.count;
    __block NSUInteger done = 0;
    NSMutableArray *loaded = [NSMutableArray array];
    for (UIDragItem *item in _items) {
        if (![item.itemProvider canLoadObjectOfClass:aClass]) {
            progress.completedUnitCount = ++done;
            continue;
        }
        [item.itemProvider loadObjectOfClass:aClass
                            completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            if (object)
                [loaded addObject:object];
            progress.completedUnitCount = ++done;
            if (done < progress.totalUnitCount)
                return;
            if (completion)
                completion(loaded);
        }];
    }
    if (done == progress.totalUnitCount && completion)
        completion(loaded);
    return progress;
}

@end
