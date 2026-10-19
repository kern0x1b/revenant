#import "darkstyle_scenario.h"
#import <dlfcn.h>
#import <objc/runtime.h>

void charon_windowed_run(UIWindow *window);

// Whether the prefixed trait collection of a class is this executable's own implementation: the scenario means nothing
// about the port if the calls reach the system's, which is the answer the bare name gives.
static BOOL answers_from_app(Class cls, const char *prefixed)
{
    Dl_info self_info, inside;
    memset(&self_info, 0, sizeof(self_info));
    memset(&inside, 0, sizeof(inside));
    IMP method = class_getMethodImplementation(cls, sel_registerName(prefixed));
    return dladdr((void *)&charon_windowed_run, &self_info) && dladdr((void *)method, &inside) && inside.dli_fname && self_info.dli_fname
        && strcmp(inside.dli_fname, self_info.dli_fname) == 0;
}

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        charon_check(answers_from_app([UIView class], "charonHostTraitCollection") && answers_from_app([UIViewController class], "charonHostTraitCollection"),
                     "the port's trait collection answers for views and controllers, not the system's", @"bare name answers");
        NSArray *ours = darkstyle_scenario(window);
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        ur_agree(@"dark style through the trait chain", ours, [expected componentsSeparatedByString:@"\n"]);
    }
}
