#import <QuartzCore/CAMetalLayer.h>
#import <objc/runtime.h>

static const void *revenant_timeout_key = &revenant_timeout_key;

@implementation CAMetalLayer (RevenantTimeout)

- (BOOL)allowsNextDrawableTimeout
{
    NSNumber *value = objc_getAssociatedObject(self, revenant_timeout_key);
    return value ? value.boolValue : YES;
}

- (void)setAllowsNextDrawableTimeout:(BOOL)allows
{
    objc_setAssociatedObject(self, revenant_timeout_key, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
