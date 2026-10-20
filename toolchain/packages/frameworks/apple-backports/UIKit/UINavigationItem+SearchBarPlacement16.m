#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *RevenantPreferredSearchBarPlacementKey = &RevenantPreferredSearchBarPlacementKey;

@implementation UINavigationItem (RevenantSearchBarPlacement16)

- (UINavigationItemSearchBarPlacement)preferredSearchBarPlacement
{
    NSNumber *value = objc_getAssociatedObject(self, RevenantPreferredSearchBarPlacementKey);
    return value ? value.integerValue : UINavigationItemSearchBarPlacementAutomatic;
}

- (void)setPreferredSearchBarPlacement:(UINavigationItemSearchBarPlacement)placement
{
    objc_setAssociatedObject(self, RevenantPreferredSearchBarPlacementKey, @(placement), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UINavigationItemSearchBarPlacement)searchBarPlacement
{
    UISearchController *controller = self.searchController;
    if (controller && self.titleView == controller.searchBar)
        return UINavigationItemSearchBarPlacementInline;
    return UINavigationItemSearchBarPlacementAutomatic;
}

@end
