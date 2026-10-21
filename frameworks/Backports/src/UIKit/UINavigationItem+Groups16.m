#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantLeadingGroupsKey;
static const char RevenantTrailingGroupsKey;
static const char RevenantCenterGroupsKey;
static const char RevenantPinnedGroupKey;
static const char RevenantNavigationStyleKey;
static const char RevenantNavigationBackActionKey;
static const char RevenantTitleMenuKey;
static const char RevenantRenameDelegateKey;
static const char RevenantDocumentPropertiesKey;
static const char RevenantCustomizationKey;
static const char RevenantOverflowItemsKey;

static NSArray<UIBarButtonItem *> *revenant_visual_items(NSArray<UIBarButtonItemGroup *> *groups)
{
    NSMutableArray *items = [NSMutableArray array];
    for (UIBarButtonItemGroup *group in groups) {
        if (!group.isHidden)
            [items addObjectsFromArray:group.barButtonItems];
    }
    return items;
}

static void revenant_report_navigation_item(NSString *name)
{
    revenant_menus_say_once(@"navigation-item-16", [NSString stringWithFormat:@"UINavigationItem.%@: the iOS 6 navigation bar has no such feature, so the value is kept and read back and the bar is drawn as before", name]);
}

@implementation UINavigationItem (RevenantGroups16)

- (NSArray<UIBarButtonItemGroup *> *)leadingItemGroups
{
    return objc_getAssociatedObject(self, &RevenantLeadingGroupsKey) ?: @[];
}

- (void)setLeadingItemGroups:(NSArray<UIBarButtonItemGroup *> *)leadingItemGroups
{
    objc_setAssociatedObject(self, &RevenantLeadingGroupsKey, [leadingItemGroups copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.leftBarButtonItems = revenant_visual_items(leadingItemGroups);
}

- (NSArray<UIBarButtonItemGroup *> *)trailingItemGroups
{
    return objc_getAssociatedObject(self, &RevenantTrailingGroupsKey) ?: @[];
}

- (void)setTrailingItemGroups:(NSArray<UIBarButtonItemGroup *> *)trailingItemGroups
{
    objc_setAssociatedObject(self, &RevenantTrailingGroupsKey, [trailingItemGroups copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self revenant_applyTrailing];
}

- (UIBarButtonItemGroup *)pinnedTrailingGroup
{
    return objc_getAssociatedObject(self, &RevenantPinnedGroupKey);
}

- (void)setPinnedTrailingGroup:(UIBarButtonItemGroup *)pinnedTrailingGroup
{
    objc_setAssociatedObject(self, &RevenantPinnedGroupKey, pinnedTrailingGroup, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self revenant_applyTrailing];
}

- (void)revenant_applyTrailing
{
    NSMutableArray *visual = [NSMutableArray arrayWithArray:revenant_visual_items(self.trailingItemGroups)];
    UIBarButtonItemGroup *pinned = self.pinnedTrailingGroup;
    if (pinned && !pinned.isHidden)
        [visual addObjectsFromArray:pinned.barButtonItems];
    self.rightBarButtonItems = visual.reverseObjectEnumerator.allObjects;
}

- (NSArray<UIBarButtonItemGroup *> *)centerItemGroups
{
    return objc_getAssociatedObject(self, &RevenantCenterGroupsKey) ?: @[];
}

- (void)setCenterItemGroups:(NSArray<UIBarButtonItemGroup *> *)centerItemGroups
{
    if (centerItemGroups.count)
        revenant_report_navigation_item(@"centerItemGroups");
    objc_setAssociatedObject(self, &RevenantCenterGroupsKey, [centerItemGroups copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UINavigationItemStyle)style
{
    return (UINavigationItemStyle)[objc_getAssociatedObject(self, &RevenantNavigationStyleKey) integerValue];
}

- (void)setStyle:(UINavigationItemStyle)style
{
    if (style != UINavigationItemStyleNavigator)
        revenant_report_navigation_item(@"style");
    objc_setAssociatedObject(self, &RevenantNavigationStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIAction *)backAction
{
    return objc_getAssociatedObject(self, &RevenantNavigationBackActionKey);
}

- (void)setBackAction:(UIAction *)backAction
{
    if (backAction)
        revenant_report_navigation_item(@"backAction");
    objc_setAssociatedObject(self, &RevenantNavigationBackActionKey, backAction, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIMenu *(^)(NSArray<UIMenuElement *> *))titleMenuProvider
{
    return objc_getAssociatedObject(self, &RevenantTitleMenuKey);
}

- (void)setTitleMenuProvider:(UIMenu *(^)(NSArray<UIMenuElement *> *))titleMenuProvider
{
    if (titleMenuProvider)
        revenant_report_navigation_item(@"titleMenuProvider");
    objc_setAssociatedObject(self, &RevenantTitleMenuKey, titleMenuProvider, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (id<UINavigationItemRenameDelegate>)renameDelegate
{
    return [objc_getAssociatedObject(self, &RevenantRenameDelegateKey) nonretainedObjectValue];
}

- (void)setRenameDelegate:(id<UINavigationItemRenameDelegate>)renameDelegate
{
    objc_setAssociatedObject(self, &RevenantRenameDelegateKey, renameDelegate ? [NSValue valueWithNonretainedObject:renameDelegate] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIDocumentProperties *)documentProperties
{
    return objc_getAssociatedObject(self, &RevenantDocumentPropertiesKey);
}

- (void)setDocumentProperties:(UIDocumentProperties *)documentProperties
{
    objc_setAssociatedObject(self, &RevenantDocumentPropertiesKey, documentProperties, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)customizationIdentifier
{
    return objc_getAssociatedObject(self, &RevenantCustomizationKey);
}

- (void)setCustomizationIdentifier:(NSString *)customizationIdentifier
{
    objc_setAssociatedObject(self, &RevenantCustomizationKey, customizationIdentifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIDeferredMenuElement *)additionalOverflowItems
{
    return objc_getAssociatedObject(self, &RevenantOverflowItemsKey);
}

- (void)setAdditionalOverflowItems:(UIDeferredMenuElement *)additionalOverflowItems
{
    if (additionalOverflowItems)
        revenant_report_navigation_item(@"additionalOverflowItems");
    objc_setAssociatedObject(self, &RevenantOverflowItemsKey, additionalOverflowItems, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id<UIPopoverPresentationControllerSourceItem>)overflowPresentationSource
{
    return nil;
}

@end
