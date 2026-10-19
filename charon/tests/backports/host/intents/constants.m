// constants.m - every extern constant this slice carries, the port's value beside the system's.
//
// One source built twice: once with Apple's Intents.framework and once with the port's
// IntentsConstantsNN.m objects linked in front of it, so every line below is the port's answer
// beside the host's.  A value is a string, so the comparison is text; the port's own is read
// from the port object, the system's from the framework, and the two are diffed.
//
// The plant is the point.  PLANTS=one-wrong puts a value in the port's table that the system does
// not have, and the line must go RED; a differential that cannot fail is not a check.
//
//   xcrun clang -fobjc-arc constants.m -framework Intents -framework Foundation -o constants && ./constants
//   PLANTS=one-wrong ./constants

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <stdio.h>

static NSUInteger gRed, gLines;
static BOOL gPlant;

// Every name the slice carries, and the value the host holds for it.  The table is here and
// not generated into the source, so a value the host changes is a change the check sees and not
// a change to a header: the emitter writes the port's object files from the same dump, and this
// reads the port's objects and the host's framework in one process.
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
            // The port's own, by symbol - and WHICH image answered, because
            // /System/Library/Frameworks/Intents.framework exports these names too, and a
            // dlsym that took the framework's would compare the framework with itself and
            // report a pass for a port that carries nothing.  That is not hypothetical: the
            // first build of this check, with the port's objects left out, said
            // "83 lines, 0 red -> PASS".  So the answer is only the port's if the image it
            // came from is not the system's Intents.
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
