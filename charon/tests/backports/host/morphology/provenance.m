// Which image answered, for the two sides of the differential.
//
// The harness renames the port's five classes and links them beside the host's five in one process,
// so "the two answers differ" would be meaningless if both sends had gone to one class. This prints,
// for a selector each side implements and a selector only the port has, the image the IMP came from:
// dladdr on the IMP, so the answer is the loader's and not this file's opinion.
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
        Class portMorph = NSClassFromString(@"charonHostNSMorphology");
        Class hostPronoun = NSClassFromString(@"NSMorphologyPronoun");
        Class portPronoun = NSClassFromString(@"charonHostNSMorphologyPronoun");
        printf("provenance: the two classes the differential compares\n");
        where("host  +[NSMorphology customPronounFor...]", hostMorph, @selector(customPronounForLanguage:), YES);
        where("port  +[charonHostNSMorphology ...]", portMorph, @selector(customPronounForLanguage:), YES);
        where("host  +[NSMorphologyPronoun isSupported...]", hostPronoun, @selector(isSupportedForLanguage:), YES);
        where("port  +[charonHostNSMorphologyPronoun..]", portPronoun, @selector(isSupportedForLanguage:), YES);
        // a selector ONLY the port declares, so the host side must be absent
        printf("  %-34s %s\n", "host  -[NSMorphology grammaticalCase]",
               class_getInstanceMethod(hostMorph, @selector(grammaticalCase)) ? "PRESENT" : "absent (ios17 name)");
        where("port  -[charonHostNSMorphological...]", portMorph, @selector(grammaticalCase), NO);
        return 0;
    }
}
