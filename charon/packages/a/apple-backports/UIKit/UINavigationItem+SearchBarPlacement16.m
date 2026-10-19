#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *CharonPreferredSearchBarPlacementKey = &CharonPreferredSearchBarPlacementKey;

@implementation UINavigationItem (CharonSearchBarPlacement16)

- (UINavigationItemSearchBarPlacement)preferredSearchBarPlacement
{
    NSNumber *value = objc_getAssociatedObject(self, CharonPreferredSearchBarPlacementKey);
    return value ? value.integerValue : UINavigationItemSearchBarPlacementAutomatic;
}

- (void)setPreferredSearchBarPlacement:(UINavigationItemSearchBarPlacement)placement
{
    objc_setAssociatedObject(self, CharonPreferredSearchBarPlacementKey, @(placement), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UINavigationItemSearchBarPlacement)searchBarPlacement
{
    // The search bar is the title view, in the row of the bar itself.
    UISearchController *controller = self.searchController;
    if (controller && self.titleView == controller.searchBar)
        return UINavigationItemSearchBarPlacementInline;
    return UINavigationItemSearchBarPlacementAutomatic;
}

@end
