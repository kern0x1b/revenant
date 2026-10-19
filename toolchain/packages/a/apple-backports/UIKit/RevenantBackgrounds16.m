#import <UIKit/UIKit.h>
#import "CharonLists.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static UITableView *CharonTableOfView(UIView *view)
{
    for (UIView *candidate = view.superview; candidate; candidate = candidate.superview)
        if ([candidate isKindOfClass:[UITableView class]])
            return (UITableView *)candidate;
    return nil;
}

static UIBackgroundConfiguration *CharonBackgroundForTable(UITableViewStyle style, BOOL headerFooter)
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

@implementation UICollectionViewCell (CharonBackgroundConfiguration16)

- (UIBackgroundConfiguration *)defaultBackgroundConfiguration
{
    UICollectionLayoutListConfiguration *list = [self charon_layoutListConfiguration];
    if (!list)
        return nil;
    switch ([list charon_appearance]) {
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

@implementation UITableViewCell (CharonBackgroundConfiguration16)

- (UIBackgroundConfiguration *)defaultBackgroundConfiguration
{
    UITableView *table = CharonTableOfView(self);
    return table ? CharonBackgroundForTable(table.style, NO) : nil;
}

@end

@implementation UITableViewHeaderFooterView (CharonBackgroundConfiguration16)

- (UIBackgroundConfiguration *)defaultBackgroundConfiguration
{
    UITableView *table = CharonTableOfView(self);
    return table ? CharonBackgroundForTable(table.style, YES) : nil;
}

@end
