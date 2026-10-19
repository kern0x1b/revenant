#import <QuartzCore/CAMetalLayer.h>
#import <objc/runtime.h>

static const void *charon_timeout_key = &charon_timeout_key;

@implementation CAMetalLayer (CharonTimeout)

- (BOOL)allowsNextDrawableTimeout
{
    NSNumber *value = objc_getAssociatedObject(self, charon_timeout_key);
    return value ? value.boolValue : YES;
}

- (void)setAllowsNextDrawableTimeout:(BOOL)allows
{
    objc_setAssociatedObject(self, charon_timeout_key, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
