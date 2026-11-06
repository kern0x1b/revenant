#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *RevenantLargeTitleAttributesKey = &RevenantLargeTitleAttributesKey;

@implementation UINavigationBar (RevenantLargeTitles)

- (NSDictionary<NSAttributedStringKey, id> *)largeTitleTextAttributes
{
    return objc_getAssociatedObject(self, RevenantLargeTitleAttributesKey);
}

- (void)setLargeTitleTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    objc_setAssociatedObject(self, RevenantLargeTitleAttributesKey, [attributes copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

