#import "CharonLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char CharonEditingKey;
static const char CharonSelectionDuringEditingKey;
static const char CharonMultipleDuringEditingKey;

static BOOL charon_collection_editing(UICollectionView *view)
{
    return [objc_getAssociatedObject(view, &CharonEditingKey) boolValue];
}

static void charon_collection_set_editing(UICollectionView *view, BOOL editing)
{
    editing = editing ? YES : NO;
    if (charon_collection_editing(view) == editing)
        return;
    objc_setAssociatedObject(view, &CharonEditingKey, [NSNumber numberWithBool:editing], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UICollectionViewCell *cell in view.visibleCells) {
        charon_request_update(cell);
        [cell setNeedsLayout];
        [cell layoutIfNeeded];
    }
}

__attribute__((constructor)) static void charon_install_collection_editing(void)
{
    if ([[[UIDevice currentDevice] systemVersion] compare:@"14.0" options:NSNumericSearch] != NSOrderedAscending)
        return;
    Class cls = [UICollectionView class];
    class_replaceMethod(cls, @selector(isEditing), imp_implementationWithBlock(^BOOL(UICollectionView *view) {
        return charon_collection_editing(view);
    }), "c@:");
    class_replaceMethod(cls, NSSelectorFromString(@"setEditing:"), imp_implementationWithBlock(^(UICollectionView *view, BOOL editing) {
        charon_collection_set_editing(view, editing);
    }), "v@:c");
}

@implementation UICollectionView (CharonEditing)

- (BOOL)isEditing
{
    return charon_collection_editing(self);
}

- (void)setEditing:(BOOL)editing
{
    charon_collection_set_editing(self, editing);
}

- (BOOL)allowsSelectionDuringEditing
{
    return [objc_getAssociatedObject(self, &CharonSelectionDuringEditingKey) boolValue];
}

- (void)setAllowsSelectionDuringEditing:(BOOL)allowsSelectionDuringEditing
{
    objc_setAssociatedObject(self, &CharonSelectionDuringEditingKey, @(allowsSelectionDuringEditing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsMultipleSelectionDuringEditing
{
    return [objc_getAssociatedObject(self, &CharonMultipleDuringEditingKey) boolValue];
}

- (void)setAllowsMultipleSelectionDuringEditing:(BOOL)allowsMultipleSelectionDuringEditing
{
    objc_setAssociatedObject(self, &CharonMultipleDuringEditingKey, @(allowsMultipleSelectionDuringEditing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (allowsMultipleSelectionDuringEditing)
        objc_setAssociatedObject(self, &CharonSelectionDuringEditingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)charon_editing
{
    return charon_collection_editing(self);
}

@end
