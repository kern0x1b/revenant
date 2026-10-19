#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *CharonPrefersLargeTitlesKey = &CharonPrefersLargeTitlesKey;
static const void *CharonLargeTitleAttributesKey = &CharonLargeTitleAttributesKey;
static const void *CharonLargeTitleModeKey = &CharonLargeTitleModeKey;

@implementation UINavigationBar (CharonLargeTitles)

- (BOOL)prefersLargeTitles
{
    return [objc_getAssociatedObject(self, CharonPrefersLargeTitlesKey) boolValue];
}

- (void)setPrefersLargeTitles:(BOOL)prefers
{
    objc_setAssociatedObject(self, CharonPrefersLargeTitlesKey, @(prefers), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary<NSAttributedStringKey, id> *)largeTitleTextAttributes
{
    return objc_getAssociatedObject(self, CharonLargeTitleAttributesKey);
}

- (void)setLargeTitleTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    objc_setAssociatedObject(self, CharonLargeTitleAttributesKey, [attributes copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UINavigationItem (CharonLargeTitleDisplayMode)

- (UINavigationItemLargeTitleDisplayMode)largeTitleDisplayMode
{
    return (UINavigationItemLargeTitleDisplayMode)[objc_getAssociatedObject(self, CharonLargeTitleModeKey) integerValue];
}

- (void)setLargeTitleDisplayMode:(UINavigationItemLargeTitleDisplayMode)mode
{
    objc_setAssociatedObject(self, CharonLargeTitleModeKey, @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
