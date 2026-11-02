#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void RNHostLogSubscriptProbe(void)
{
    NSMutableDictionary *probe = [NSMutableDictionary dictionary];
    probe[@"kept"] = @1;
    @try {
        id nothing = nil;
        probe[@"kept"] = nothing;
        NSLog(@"rn-host: subscript nil removes the key, count %lu", (unsigned long)probe.count);
    } @catch (NSException *exception) {
        NSLog(@"rn-host: subscript nil raises %@: %@", exception.name, exception.reason);
    }
}

@interface RNHostFoundationShim : NSObject
@end

@implementation RNHostFoundationShim

+ (void)load
{
    RNHostLogSubscriptProbe();
    if (getenv("RNHOST_NO_SHIM")) return;
    Class concrete = [[NSMutableDictionary dictionary] class];
    SEL selector = @selector(setObject:forKeyedSubscript:);
    Method original = class_getInstanceMethod(concrete, selector);
    if (!original) return;
    IMP previous = method_getImplementation(original);
    IMP replacement = imp_implementationWithBlock(^(id self, id object, id key) {
        if (object == nil) {
            [self removeObjectForKey:key];
            return;
        }
        ((void (*)(id, SEL, id, id))previous)(self, selector, object, key);
    });
    method_setImplementation(original, replacement);
    NSLog(@"rn-host: NSMutableDictionary setObject:forKeyedSubscript: nil now removes the key (%@)", NSStringFromClass(concrete));
}

@end
