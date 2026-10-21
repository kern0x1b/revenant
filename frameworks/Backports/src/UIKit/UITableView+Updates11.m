#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantTableUpdatesKey;
static const char RevenantTableSafeAreaKey;
static const char RevenantTableSeparatorReferenceKey;
static const char RevenantCollectionUpdatesKey;
static const char RevenantCollectionCadenceKey;

static void revenant_count_updates(id view, const void *key, NSInteger delta)
{
    NSInteger count = [objc_getAssociatedObject(view, key) integerValue] + delta;
    objc_setAssociatedObject(view, key, count > 0 ? @(count) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface RevenantUpdateTracking11 : NSObject
@end

@implementation RevenantUpdateTracking11

+ (void)load
{
    if ([UITableView instancesRespondToSelector:@selector(hasUncommittedUpdates)])
        return;
    Class table = [UITableView class];
    SEL begin = @selector(beginUpdates), end = @selector(endUpdates);
    void (*originalBegin)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation(table, begin);
    void (*originalEnd)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation(table, end);
    class_replaceMethod(table, begin, imp_implementationWithBlock(^(UITableView *view) {
        revenant_count_updates(view, &RevenantTableUpdatesKey, 1);
        originalBegin(view, begin);
    }), "v@:");
    class_replaceMethod(table, end, imp_implementationWithBlock(^(UITableView *view) {
        originalEnd(view, end);
        revenant_count_updates(view, &RevenantTableUpdatesKey, -1);
    }), "v@:");
    Class collection = [UICollectionView class];
    SEL batch = @selector(performBatchUpdates:completion:);
    void (*originalBatch)(id, SEL, void (^)(void), void (^)(BOOL)) = (void (*)(id, SEL, void (^)(void), void (^)(BOOL)))class_getMethodImplementation(collection, batch);
    class_replaceMethod(collection, batch, imp_implementationWithBlock(^(UICollectionView *view, void (^updates)(void), void (^completion)(BOOL)) {
        revenant_count_updates(view, &RevenantCollectionUpdatesKey, 1);
        originalBatch(view, batch, updates, completion);
        revenant_count_updates(view, &RevenantCollectionUpdatesKey, -1);
    }), "v@:@?@?");
}

@end

@implementation UITableView (RevenantUpdates11)

- (BOOL)hasUncommittedUpdates
{
    return [objc_getAssociatedObject(self, &RevenantTableUpdatesKey) integerValue] > 0;
}

- (BOOL)insetsContentViewsToSafeArea
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantTableSafeAreaKey);
    return stored ? stored.boolValue : YES;
}

- (void)setInsetsContentViewsToSafeArea:(BOOL)insetsContentViewsToSafeArea
{
    objc_setAssociatedObject(self, &RevenantTableSafeAreaKey, @(insetsContentViewsToSafeArea), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UITableViewSeparatorInsetReference)separatorInsetReference
{
    return (UITableViewSeparatorInsetReference)[objc_getAssociatedObject(self, &RevenantTableSeparatorReferenceKey) integerValue];
}

- (void)setSeparatorInsetReference:(UITableViewSeparatorInsetReference)separatorInsetReference
{
    if (separatorInsetReference != UITableViewSeparatorInsetFromCellEdges)
        revenant_menus_say_once(@"table-separator-reference", @"UITableView.separatorInsetReference: the iOS 6 table view has no automatic separator insets, so the reference is kept and read back and separatorInset is applied from the cell edges as before");
    objc_setAssociatedObject(self, &RevenantTableSeparatorReferenceKey, @(separatorInsetReference), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UICollectionView (RevenantUpdates11)

- (BOOL)hasUncommittedUpdates
{
    return [objc_getAssociatedObject(self, &RevenantCollectionUpdatesKey) integerValue] > 0;
}

- (UICollectionViewReorderingCadence)reorderingCadence
{
    return (UICollectionViewReorderingCadence)[objc_getAssociatedObject(self, &RevenantCollectionCadenceKey) integerValue];
}

- (void)setReorderingCadence:(UICollectionViewReorderingCadence)reorderingCadence
{
    objc_setAssociatedObject(self, &RevenantCollectionCadenceKey, @(reorderingCadence), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
