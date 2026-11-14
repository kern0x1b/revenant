#import "check.h"
#import "../revenant_alias.h"

REVENANT_ALIAS_STATE(ProbeAlias, NSObject,
    int _value;
)

REVENANT_ALIAS_ADOPTS(ProbeAlias, NSCopying, NSSecureCoding)

@implementation REVENANT_ALIAS_CLASS(ProbeAlias) (Probe)

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

REVENANT_ALIAS_STATE(ProbeWrapped, NSObject, )

@implementation REVENANT_ALIAS_CLASS(ProbeWrapped) (Probe)

+ (int)answer
{
    return 2;
}

@end

static int probe_answer_system(id self, SEL _cmd)
{
    return 1;
}

static int probe_answer_wrapped(id self, SEL _cmd)
{
    return 99;
}

static BOOL wrap_negative;

static void check_wrapper_reaches_proxy(void)
{
    SEL selector = @selector(answer);
    Class system = objc_allocateClassPair([NSObject class], "ProbeWrappedSystem", 0);
    class_addMethod(object_getClass(system), selector, (IMP)probe_answer_system, "i@:");
    objc_registerClassPair(system);
    Class proxy = objc_getClass("RevenantProbeWrapped");
    Method adopted = class_getClassMethod(proxy, selector);
    method_setImplementation(adopted, class_getMethodImplementation(object_getClass(system), selector));
    revenant_check([(id)proxy answer] == 1, "the proxy yields to the system implementation the way the loader makes it", @"it does not");
    IMP original;
    if (wrap_negative) {
        Method method = class_getClassMethod(system, selector);
        original = method_getImplementation(method);
        method_setImplementation(method, (IMP)probe_answer_wrapped);
    } else {
        original = revenant_alias_wrap_class_method(system, "RevenantProbeWrapped", selector, (IMP)probe_answer_wrapped);
    }
    revenant_check(original == (IMP)probe_answer_system, "the wrapping hands back the system implementation", @"another one");
    revenant_check([(id)system answer] == 99, "the system class runs the wrapper", @"it does not");
    revenant_check([(id)proxy answer] == 99, "the proxy, which an app or a translated library binds to, runs the wrapper too", @"it still runs the system implementation");
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    wrap_negative = argc > 1 && strcmp(argv[1], "--negative-wrap") == 0;
    check_wrapper_reaches_proxy();
    Class declared = objc_getClass("RevenantProbeAlias");
    Class alias = objc_getClass("ProbeAlias");
    revenant_check(declared != Nil, "the class the source declares is registered", @"Nil");
    revenant_check(alias != Nil, "the alias is registered under the SDK's name", @"Nil");
    Protocol *asked = revenant_negative ? @protocol(NSFastEnumeration) : @protocol(NSCopying);
    revenant_check(class_conformsToProtocol(declared, asked), "the declared class adopts NSCopying", @"no");
    revenant_check(class_conformsToProtocol(alias, asked), "the alias adopts NSCopying for class_conformsToProtocol, which does not look at superclasses", @"no");
    revenant_check(class_conformsToProtocol(alias, @protocol(NSSecureCoding)), "the alias adopts NSSecureCoding for class_conformsToProtocol", @"no");
    revenant_check([alias conformsToProtocol:@protocol(NSCopying)], "the alias adopts NSCopying for conformsToProtocol:", @"no");
    id instance = [[alias alloc] init];
    revenant_check([instance conformsToProtocol:@protocol(NSCopying)], "an instance of the alias conforms to NSCopying", @"no");
    revenant_check(!class_conformsToProtocol(alias, @protocol(NSFastEnumeration)), "the alias adopts only what the source lists", @"it adopts NSFastEnumeration");
    return revenant_finish();
}
