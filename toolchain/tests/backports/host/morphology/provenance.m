#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <stdio.h>

static void where(const char *label, id object, SEL selector, BOOL classMethod)
{
    IMP imp = classMethod ? class_getMethodImplementation(object, selector)
                          : class_getInstanceMethod(object, selector) ? method_getImplementation(class_getInstanceMethod(object, selector)) : NULL;
    Dl_info info;
    memset(&info, 0, sizeof info);
    const char *image = "(none)";
    const char *symbol = "(none)";
    if (imp && dladdr((const void *)imp, &info) && info.dli_fname) {
        image = info.dli_fname;
        symbol = info.dli_sname ? info.dli_sname : "(no symbol)";
    }
    printf("  %-34s %-40s %s\n", label, image, symbol);
}

int main(void)
{
    @autoreleasepool {
        Class hostMorph = NSClassFromString(@"NSMorphology");
        Class portMorph = NSClassFromString(@"revenantHostNSMorphology");
        Class hostPronoun = NSClassFromString(@"NSMorphologyPronoun");
        Class portPronoun = NSClassFromString(@"revenantHostNSMorphologyPronoun");
        printf("provenance: the two classes the differential compares\n");
        where("host  +[NSMorphology customPronounFor...]", hostMorph, @selector(customPronounForLanguage:), YES);
        where("port  +[revenantHostNSMorphology ...]", portMorph, @selector(customPronounForLanguage:), YES);
        where("host  +[NSMorphologyPronoun isSupported...]", hostPronoun, @selector(isSupportedForLanguage:), YES);
        where("port  +[revenantHostNSMorphologyPronoun..]", portPronoun, @selector(isSupportedForLanguage:), YES);
        printf("  %-34s %s\n", "host  -[NSMorphology grammaticalCase]",
               class_getInstanceMethod(hostMorph, @selector(grammaticalCase)) ? "PRESENT" : "absent (ios17 name)");
        where("port  -[revenantHostNSMorphological...]", portMorph, @selector(grammaticalCase), NO);
        return 0;
    }
}
