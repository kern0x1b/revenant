#import "RevenantLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantEditingKey;
static const char RevenantSelectionDuringEditingKey;
static const char RevenantMultipleDuringEditingKey;

static BOOL revenant_collection_editing(UICollectionView *view)
{
    return [objc_getAssociatedObject(view, &RevenantEditingKey) boolValue];
}

static void revenant_collection_set_editing(UICollectionView *view, BOOL editing)
{
    editing = editing ? YES : NO;
    if (revenant_collection_editing(view) == editing)
        return;
    objc_setAssociatedObject(view, &RevenantEditingKey, [NSNumber numberWithBool:editing], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UICollectionViewCell *cell in view.visibleCells) {
        revenant_request_update(cell);
        [cell setNeedsLayout];
        [cell layoutIfNeeded];
    }
}

__attribute__((constructor)) static void revenant_install_collection_editing(void)
{
    if ([[[UIDevice currentDevice] systemVersion] compare:@"14.0" options:NSNumericSearch] != NSOrderedAscending)
        return;
    Class cls = [UICollectionView class];
    class_replaceMethod(cls, @selector(isEditing), imp_implementationWithBlock(^BOOL(UICollectionView *view) {
        return revenant_collection_editing(view);
    }), "c@:");
    class_replaceMethod(cls, NSSelectorFromString(@"setEditing:"), imp_implementationWithBlock(^(UICollectionView *view, BOOL editing) {
        revenant_collection_set_editing(view, editing);
    }), "v@:c");
}

@implementation UICollectionView (RevenantEditing)

- (BOOL)isEditing
{
    return revenant_collection_editing(self);
}

- (void)setEditing:(BOOL)editing
{
    revenant_collection_set_editing(self, editing);
}

- (BOOL)allowsSelectionDuringEditing
{
    return [objc_getAssociatedObject(self, &RevenantSelectionDuringEditingKey) boolValue];
}

- (void)setAllowsSelectionDuringEditing:(BOOL)allowsSelectionDuringEditing
{
    objc_setAssociatedObject(self, &RevenantSelectionDuringEditingKey, @(allowsSelectionDuringEditing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsMultipleSelectionDuringEditing
{
    return [objc_getAssociatedObject(self, &RevenantMultipleDuringEditingKey) boolValue];
}

- (void)setAllowsMultipleSelectionDuringEditing:(BOOL)allowsMultipleSelectionDuringEditing
{
    objc_setAssociatedObject(self, &RevenantMultipleDuringEditingKey, @(allowsMultipleSelectionDuringEditing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (allowsMultipleSelectionDuringEditing)
        objc_setAssociatedObject(self, &RevenantSelectionDuringEditingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)revenant_editing
{
    return revenant_collection_editing(self);
}

@end
