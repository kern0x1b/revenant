#import "../app/revenant_check.h"
#import <dlfcn.h>
#import <objc/runtime.h>

REVENANT_CASE(weak_class_binding)
{
    void *probe = dlopen("/usr/lib/revenant/org.revenant.backports/libRevenantWeakProbe.dylib", RTLD_NOW);
    int (*bound)(void) = probe ? (int (*)(void))dlsym(probe, "revenant_weak_probe") : NULL;
    revenant_expect_integer(@"the probe dylib loads from the backports folder", probe != NULL ? 1 : 0, 1);
    revenant_expect_integer(@"the backport registers NSDateInterval", objc_getClass("NSDateInterval") != nil ? 1 : 0, 1);
    revenant_expect_integer(@"a weak import bound through Foundation.framework alone reads nil", bound ? bound() : -1, negative ? 1 : 0);
}
