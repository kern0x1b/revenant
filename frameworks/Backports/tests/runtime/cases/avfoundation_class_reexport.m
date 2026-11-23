#import "../app/revenant_check.h"
#import <dlfcn.h>
#import <objc/runtime.h>

typedef Class (*revenant_stale_function)(void);

static NSString *const kStaleUser = @"/usr/lib/revenant/org.revenant.backports/libRevenantStaleUserProbe.dylib";
static NSString *const kSystemImage = @"/System/Library/Frameworks/AVFoundation.framework/AVFoundation";

// An image linked against a Backports build that defined AVSampleBufferDisplayLayer binds the class by name to
// libAVFoundationBackports. The library now leaves the class to the system and re-exports it, so that image still loads,
// and what it bound is the system's class, not a second one.
REVENANT_CASE(avfoundation_class_reexport)
{
    void *probe = dlopen([kStaleUser UTF8String], RTLD_NOW);
    const char *error = probe ? NULL : dlerror();
    revenant_stale_function bound_class = probe ? (revenant_stale_function)dlsym(probe, "revenant_stale_user_class") : NULL;
    revenant_stale_function bound_metaclass = probe ? (revenant_stale_function)dlsym(probe, "revenant_stale_user_metaclass") : NULL;
    Class bound = bound_class ? bound_class() : Nil;
    Class named = objc_getClass("AVSampleBufferDisplayLayer");
    revenant_expect_true(@"an image bound to AVSampleBufferDisplayLayer in libAVFoundationBackports loads, so the library still exports it",
                         (probe != NULL) != (BOOL)negative,
                         [NSString stringWithFormat:@"%s", error ?: "loaded"]);
    revenant_expect_true(@"the class that image bound is the class the runtime names",
                         (bound != Nil && bound == named) != (BOOL)negative,
                         [NSString stringWithFormat:@"bound %p, named %p", (void *)bound, (void *)named]);
    revenant_expect_true(@"the metaclass it bound is the metaclass of that class",
                         (bound_metaclass != NULL && bound_metaclass() == object_getClass(named)) != (BOOL)negative,
                         [NSString stringWithFormat:@"bound %p, expected %p", bound_metaclass ? (void *)bound_metaclass() : NULL, (void *)object_getClass(named)]);
    const char *image = bound ? class_getImageName(bound) : NULL;
    revenant_expect_true(@"the class lives in the system's AVFoundation, not in a Backports library",
                         (image != NULL && strcmp(image, [kSystemImage UTF8String]) == 0) != (BOOL)negative,
                         [NSString stringWithFormat:@"image %s", image ?: "none"]);
    NSUInteger count = revenant_registered_count("AVSampleBufferDisplayLayer");
    revenant_expect_true(@"the runtime registers one class of that name",
                         (count == 1) != (BOOL)negative,
                         [NSString stringWithFormat:@"classes named AVSampleBufferDisplayLayer: %lu", (unsigned long)count]);
}
