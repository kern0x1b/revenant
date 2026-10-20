#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantConfigurationExpensiveKey;
static char RevenantConfigurationConstrainedKey;

static void revenant_configuration_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SEL selector = @selector(copyWithZone:);
        Method method = class_getInstanceMethod([NSURLSessionConfiguration class], selector);
        if (!method)
            return;
        IMP original = method_getImplementation(method);
        class_replaceMethod([NSURLSessionConfiguration class], selector, imp_implementationWithBlock(^id(NSURLSessionConfiguration *configuration, NSZone *zone) {
            id copy = ((id (*)(id, SEL, NSZone *))original)(configuration, selector, zone);
            const void *keys[2] = {&RevenantConfigurationExpensiveKey, &RevenantConfigurationConstrainedKey};
            for (int index = 0; index < 2; index++) {
                id value = objc_getAssociatedObject(configuration, keys[index]);
                if (value && copy != configuration)
                    objc_setAssociatedObject(copy, keys[index], value, OBJC_ASSOCIATION_RETAIN);
            }
            return copy;
        }), method_getTypeEncoding(method));
    });
}

@implementation NSURLSessionConfiguration (RevenantNetworkAccess)

- (BOOL)allowsExpensiveNetworkAccess
{
    NSNumber *value = objc_getAssociatedObject(self, &RevenantConfigurationExpensiveKey);
    return value ? value.boolValue : YES;
}

- (void)setAllowsExpensiveNetworkAccess:(BOOL)allows
{
    if (!allows)
        revenant_configuration_install();
    objc_setAssociatedObject(self, &RevenantConfigurationExpensiveKey, allows ? nil : @NO, OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)allowsConstrainedNetworkAccess
{
    NSNumber *value = objc_getAssociatedObject(self, &RevenantConfigurationConstrainedKey);
    return value ? value.boolValue : YES;
}

- (void)setAllowsConstrainedNetworkAccess:(BOOL)allows
{
    if (!allows)
        revenant_configuration_install();
    objc_setAssociatedObject(self, &RevenantConfigurationConstrainedKey, allows ? nil : @NO, OBJC_ASSOCIATION_RETAIN);
}

@end
