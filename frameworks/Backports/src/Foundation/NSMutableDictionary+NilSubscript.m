#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void (*revenant_original_set_subscript)(id, SEL, id, id);

static void revenant_dictionary_set_subscript(id self, SEL _cmd, id object, id key)
{
    if (object == nil && key != nil) {
        [self removeObjectForKey:key];
        return;
    }
    revenant_original_set_subscript(self, _cmd, object, key);
}

static BOOL revenant_dictionary_subscript_removes(void)
{
    NSMutableDictionary *probe = [NSMutableDictionary dictionary];
    probe[@"k"] = @1;
    @try {
        probe[@"k"] = nil;
    } @catch (NSException *exception) {
        return NO;
    }
    return probe.count == 0;
}

__attribute__((constructor)) static void revenant_dictionary_subscript_install(void)
{
    if (revenant_dictionary_subscript_removes())
        return;
    Method method = class_getInstanceMethod(object_getClass([NSMutableDictionary dictionary]), @selector(setObject:forKeyedSubscript:));
    if (method == NULL)
        return;
    revenant_original_set_subscript = (void (*)(id, SEL, id, id))method_getImplementation(method);
    method_setImplementation(method, (IMP)revenant_dictionary_set_subscript);
}
