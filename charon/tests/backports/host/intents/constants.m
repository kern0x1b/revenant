#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <stdio.h>

static NSUInteger gRed, gLines;
static BOOL gPlant;

static const char *NAMES[] = {
#include "constants-names.inc"
};
static const char *VALUES[] = {
#include "constants-values.inc"

#include <string.h>
};

static NSString *systemValue(const char *name)
{
    void *image = dlopen("/System/Library/Frameworks/Intents.framework/Intents", RTLD_LAZY);
    if (!image) return nil;
    void *address = dlsym(image, name);
    if (!address) return nil;
    return *(NSString *const *)address;
}

int main(void)
{
    @autoreleasepool {
        gPlant = [[[NSProcessInfo processInfo] environment] objectForKey:@"PLANTS"] != nil;
        printf("intents-1b constants, PLANTS=%s, %lu names\n",
               gPlant ? "one-wrong" : "(none)", (unsigned long)(sizeof(NAMES) / sizeof(*NAMES)));

        NSUInteger count = sizeof(NAMES) / sizeof(*NAMES);
        for (NSUInteger i = 0; i < count; i++) {
            const char *name = NAMES[i];
            void *port = dlsym(RTLD_DEFAULT, name);
            const char *from = port ? "??" : "absent";
            if (port) {
                Dl_info info;
                from = (dladdr(port, &info) && info.dli_fname) ? info.dli_fname : "unknown image";
            }
            BOOL isSystem = from && strstr(from, "/System/Library/Frameworks/Intents.framework") != NULL;
            NSString *mine = (port && !isSystem) ? *(NSString *const *)port : nil;
            NSString *theirs = systemValue(name);
            gLines++;

            NSString *expected = @(VALUES[i]);
            if (gPlant && i == 0)
                expected = @"planted-value-the-system-does-not-have";

            BOOL havePort = mine != nil;
            BOOL haveSystem = theirs != nil;
            BOOL sameText = havePort && haveSystem && [mine isEqual:theirs];
            BOOL sameTable = haveSystem && [expected isEqual:theirs];
            BOOL ok = havePort && sameText && sameTable;
            if (!ok) gRed++;
            if (!ok || getenv("CONSTANTS_VERBOSE") != NULL) {
                printf("  %-52s %s  port %-46s system %-46s table %s\n", name,
                       ok ? "ok  " : "RED ", havePort ? [mine UTF8String] : "(absent)",
                       haveSystem ? [theirs UTF8String] : "(absent)",
                       haveSystem && [expected isEqual:theirs] ? "matches" : "DIFFERS");
            }
        }
        printf("constants: %lu lines, %lu red  ->  %s\n", (unsigned long)gLines, (unsigned long)gRed,
               gRed == 0 ? "PASS" : "FAIL");
    }
    return gRed == 0 ? 0 : 1;
}
