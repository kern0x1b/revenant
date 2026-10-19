#import <UIKit/UIKit.h>
#import "RevenantLists.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static UITableView *RevenantTableOfView(UIView *view)
{
    for (UIView *candidate = view.superview; candidate; candidate = candidate.superview)
        if ([candidate isKindOfClass:[UITableView class]])
            return (UITableView *)candidate;
    return nil;
}

static UIBackgroundConfiguration *RevenantBackgroundForTable(UITableViewStyle style, BOOL headerFooter)
{
    switch (style) {
    case UITableViewStylePlain:
        return headerFooter ? [UIBackgroundConfiguration listPlainHeaderFooterConfiguration] : [UIBackgroundConfiguration listPlainCellConfiguration];
    case UITableViewStyleGrouped:
    case UITableViewStyleInsetGrouped:
        return headerFooter ? [UIBackgroundConfiguration listGroupedHeaderFooterConfiguration] : [UIBackgroundConfiguration listGroupedCellConfiguration];
    }
    return nil;
}

@implementation UICollectionViewCell (RevenantBackgroundConfiguration16)

- (UIBackgroundConfiguration *)defaultBackgroundConfiguration
{
    UICollectionLayoutListConfiguration *list = [self revenant_layoutListConfiguration];
    if (!list)
        return nil;
    switch ([list revenant_appearance]) {
    case UICollectionLayoutListAppearanceGrouped:
    case UICollectionLayoutListAppearanceInsetGrouped:
        return [UIBackgroundConfiguration listGroupedCellConfiguration];
    case UICollectionLayoutListAppearanceSidebar:
        return [UIBackgroundConfiguration listSidebarCellConfiguration];
    case UICollectionLayoutListAppearancePlain:
    case UICollectionLayoutListAppearanceSidebarPlain:
        return [UIBackgroundConfiguration listPlainCellConfiguration];
    }
    return nil;
}

@end

@implementation UITableViewCell (RevenantBackgroundConfiguration16)

- (UIBackgroundConfiguration *)defaultBackgroundConfiguration
{
    UITableView *table = RevenantTableOfView(self);
    return table ? RevenantBackgroundForTable(table.style, NO) : nil;
}

@end

@implementation UITableViewHeaderFooterView (RevenantBackgroundConfiguration16)

- (UIBackgroundConfiguration *)defaultBackgroundConfiguration
{
    UITableView *table = RevenantTableOfView(self);
    return table ? RevenantBackgroundForTable(table.style, YES) : nil;
}

@end
