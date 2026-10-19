#import <UIKit/UIKit.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>

#import "UIDropCoordinators.h"

// The abstract session both a drag and a drop are, and the loading that is shared between them.
//
// UIDragDropSession is the base UIKit declares for both, and the release does not have it: the
// ladder carries no rung that exports the name, which is why the port builds it. The port's own
// sessions in CharonDragSession.h are its subclasses in spirit -- a drag session and a drop session
// each hold their items and answer where the drag is -- and this class is the part they share, the
// questions about the items the drag carries.
//
// What it answers is not a constant. The release can load an object out of an item provider, and so
// can this: canLoadObjectsOfClass: asks each item's provider, and loadObjectsOfClass:completion: goes
// through the providers and reports real progress, one unit per item, which is the count a caller
// can watch.

@interface UIDragDropSession : NSObject <UIDropSession>
@property (nonatomic, strong) NSArray<UIDragItem *> *items;
@property (nonatomic, assign) CGPoint location;
@property (nonatomic, weak) UIView *owner;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, assign) UIDropSessionProgressIndicatorStyle progressIndicatorStyle;
// A session of this port's own is its own local drag session: there is no other one to be had, since
// nothing outside the application starts a drag on this release.
@property (nonatomic, strong, nullable) id<UIDragSession> localDragSession;
@end

@implementation UIDragDropSession
@synthesize items = _items;
@synthesize location = _location;
@synthesize owner = _owner;
@synthesize progress = _progress;
@synthesize progressIndicatorStyle = _progressIndicatorStyle;
@synthesize localDragSession = _localDragSession;

// The plain -init reaches the same place as the designated one, so a session made with alloc/init is
// not half built. It used to be: only -initWithItems: created the NSProgress, and
// -loadObjectsOfClass:completion: hands back exactly that object, so a caller that allocated and
// initialised a session the obvious way was handed nil where the release's own load hands back a
// progress - measured, tests/backports/host/dragdrop: "FAIL drop session load returns a finished
// progress". One initialiser path, and every session has a progress to report into.
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

// Whether this session may move its items, and whether it is confined to the application that began
// it: a drag on this release stays in that application, so the answer is YES.
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

// Whether the release can load the class asked for, which is the provider's own answer for each
// item: no item that can, means this session cannot.
- (BOOL)canLoadObjectsOfClass:(Class<NSItemProviderReading>)aClass
{
    for (UIDragItem *item in _items)
        if ([item.itemProvider canLoadObjectOfClass:aClass])
            return YES;
    return NO;
}

// The objects the release can load, loaded through the providers that carry them, with the progress
// one unit per item so a caller can watch it. The completion is called with whatever loaded: a
// provider that cannot load its class contributes nothing rather than failing the whole session,
// which is what the release's own load of a heterogeneous set does.
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
    // Nothing to wait for when no item could be asked, so the completion is called here.
    if (done == progress.totalUnitCount && completion)
        completion(loaded);
    return progress;
}

@end
