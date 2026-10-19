#import "darkstyle_scenario.h"
#import <dlfcn.h>
#import <objc/runtime.h>

void revenant_windowed_run(UIWindow *window);

static BOOL answers_from_app(Class cls, const char *prefixed)
{
    Dl_info self_info, inside;
    memset(&self_info, 0, sizeof(self_info));
    memset(&inside, 0, sizeof(inside));
    IMP method = class_getMethodImplementation(cls, sel_registerName(prefixed));
    return dladdr((void *)&revenant_windowed_run, &self_info) && dladdr((void *)method, &inside) && inside.dli_fname && self_info.dli_fname
        && strcmp(inside.dli_fname, self_info.dli_fname) == 0;
}

void revenant_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        revenant_check(answers_from_app([UIView class], "revenantHostTraitCollection") && answers_from_app([UIViewController class], "revenantHostTraitCollection"),
                     "the port's trait collection answers for views and controllers, not the system's", @"bare name answers");
        NSArray *ours = darkstyle_scenario(window);
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("REVENANT_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        ur_agree(@"dark style through the trait chain", ours, [expected componentsSeparatedByString:@"\n"]);
    }
}
