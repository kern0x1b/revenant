#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *RevenantPrefersLargeTitlesKey = &RevenantPrefersLargeTitlesKey;
static const void *RevenantLargeTitleAttributesKey = &RevenantLargeTitleAttributesKey;
static const void *RevenantLargeTitleModeKey = &RevenantLargeTitleModeKey;

@implementation UINavigationBar (RevenantLargeTitles)

- (BOOL)prefersLargeTitles
{
    return [objc_getAssociatedObject(self, RevenantPrefersLargeTitlesKey) boolValue];
}

- (void)setPrefersLargeTitles:(BOOL)prefers
{
    objc_setAssociatedObject(self, RevenantPrefersLargeTitlesKey, @(prefers), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary<NSAttributedStringKey, id> *)largeTitleTextAttributes
{
    return objc_getAssociatedObject(self, RevenantLargeTitleAttributesKey);
}

- (void)setLargeTitleTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    objc_setAssociatedObject(self, RevenantLargeTitleAttributesKey, [attributes copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UINavigationItem (RevenantLargeTitleDisplayMode)

- (UINavigationItemLargeTitleDisplayMode)largeTitleDisplayMode
{
    return (UINavigationItemLargeTitleDisplayMode)[objc_getAssociatedObject(self, RevenantLargeTitleModeKey) integerValue];
}

- (void)setLargeTitleDisplayMode:(UINavigationItemLargeTitleDisplayMode)mode
{
    objc_setAssociatedObject(self, RevenantLargeTitleModeKey, @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
