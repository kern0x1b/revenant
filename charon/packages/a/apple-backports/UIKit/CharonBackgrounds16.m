#import <UIKit/UIKit.h>
#import "CharonLists.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The default appearance a cell, header or footer starts from, by the style of the list it is in.
//
// The release draws its own cells and its own page control: nothing in UIKit 6.1.3 or 12.0 answers
// -defaultBackgroundConfiguration, so a caller that asks gets no answer at all. The port already
// carries UIBackgroundConfiguration with the list styles iOS 14 added, and already reads which list
// a cell is in - CharonCompositionalLayout.h's -charon_layoutListConfiguration walks the superviews
// to the collection view and reads the layout's list configuration, and UITableViewCell's own style
// comes from -initWithStyle:reuseIdentifier:. So the answer is a lookup, not a drawing: the same
// list styles the port's cells already draw with, chosen by the list the cell is in.
//
// One file for the three classes, because it is one lookup: the list is found once and the style of
// that list picks the cell, header or footer configuration.

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