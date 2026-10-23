#import "../app/revenant_check.h"
#import <dlfcn.h>

REVENANT_CASE(missing_class_binding)
{
    void *probe = dlopen("/usr/lib/revenant/org.revenant.backports/libRevenantMissingProbe.dylib", RTLD_NOW);
    int (*missing)(void) = probe ? (int (*)(void))dlsym(probe, "revenant_missing_probe") : NULL;
    revenant_expect_integer(@"the probe loads although no image exports its class", probe != NULL ? 1 : 0, 1);
    revenant_expect_integer(@"a flat weak import with no exporter reads nil", missing ? missing() : -1, negative ? 1 : 0);
}
