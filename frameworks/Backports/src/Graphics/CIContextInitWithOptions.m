#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>

#if defined(REVENANT_HOST_BUILD)
#define REVENANT_CI_INIT_SELECTOR "initWithRevenantOptions:"
#define REVENANT_CI_INIT_LINKAGE
#else
#define REVENANT_CI_INIT_SELECTOR "initWithOptions:"
#define REVENANT_CI_INIT_LINKAGE static
#endif

REVENANT_CI_INIT_LINKAGE BOOL revenant_install_context_init(Class target, SEL selector);

@interface RevenantContextInit : NSObject
- (instancetype)initWithRevenantImplementation:(NSDictionary *)options;
@end

@implementation RevenantContextInit

- (instancetype)initWithRevenantImplementation:(NSDictionary *)options
{
    self = (RevenantContextInit *)[object_getClass(self) contextWithOptions:options];
    return self;
}

+ (void)load
{
    revenant_install_context_init([CIContext class], sel_registerName(REVENANT_CI_INIT_SELECTOR));
}

@end

REVENANT_CI_INIT_LINKAGE BOOL revenant_install_context_init(Class target, SEL selector)
{
    if (class_getInstanceMethod(target, selector))
        return NO;
    Method method = class_getInstanceMethod([RevenantContextInit class], @selector(initWithRevenantImplementation:));
    return class_addMethod(target, selector, method_getImplementation(method), method_getTypeEncoding(method));
}
