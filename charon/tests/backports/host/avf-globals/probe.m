//
//  probe.m
//  The 116 AVFoundation constants the port carries, the port against the host, in ONE binary.
//
//  run.sh compiles the port's five AVFoundationGlobals*.m with every constant name defined to its
//  `charon_host_` spelling, and links them beside this probe. The bare name is then Apple's own symbol
//  and the prefixed name is the port's own definition of the same constant, so one process reads both
//  and prints them side by side. A value the port invented cannot agree with the host's.
//
//  Two things this reads that are easy to get wrong, both measured on this host:
//
//  1. THE SYMBOL IS LOOKED UP UNDER BOTH SPELLINGS. This release's AVFoundation exports these data
//     symbols WITHOUT the Mach-O leading underscore: dlsym(RTLD_DEFAULT, "AVMediaTypeVideo") answers
//     and dlsym(RTLD_DEFAULT, "_AVMediaTypeVideo") does not. A probe that only asks for the underscore
//     finds nothing for all 116 and reports that the host does not have the framework, which is false:
//     AVPlayer, AVCaptureDevice and AVAssetExportSession all resolve through objc_getClass on the same
//     dlopen. That is what this file's own control line is here to catch, and it is why the spelling
//     that answered is printed with every row.
//
//  2. THE SHAPE OF A CONSTANT IS MEASURED, NOT DECLARED. A variable whose pointee's class is the CFString
//     class holds a string and its bytes are printed; anything else holds a number and the number is
//     printed. No typedef is written here, so a name the compiler has never heard of is read exactly as
//     well as one it has - which is every one of them, since 54 of the 116 are not in the SDK this host
//     compiles against.
//
//  Controls, so a run that examined nothing cannot pass:
//
//    AVMediaTypeVideo                      a constant the host has, and it is a string   -> HAS <string>
//    AVMediaTypeDepthData                  a second, independent string constant        -> HAS <string>
//    AVMediaTypeCharonProbeNoSuchConstant  a planted name                                -> LACKS
//    _OBJC_CLASS_$_AVPlayer                a class of the framework itself, so a run that
//                                           never loaded AVFoundation cannot pass above    -> HAS <addr>
//
//  The name list is read from a file, one name per line, and the probe says how many names it read and
//  how many rows it emitted, so run.sh can check the count against the run instead of a literal.
//
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

static Class gStringClass;

/* What one name holds, as the host's own symbol gives it. `tag` is the spelling that answered. */
static void read_value(const char *name, const char *tag, char *out, size_t size)
{
    void *address = dlsym(RTLD_DEFAULT, tag);
    const char *spelling = "bare";
    if (address == NULL) {
        char underscored[512];
        snprintf(underscored, sizeof underscored, "_%s", tag);
        address = dlsym(RTLD_DEFAULT, underscored);
        spelling = "underscored";
    }
    if (address == NULL) {
        snprintf(out, size, "LACKS");
        return;
    }
    void *held = *(void **)address;
    if (held != NULL && object_getClass((__bridge id)held) == gStringClass) {
        NSString *string = (__bridge NSString *)held;
        const char *utf8 = [string UTF8String];
        snprintf(out, size, "STR %s", utf8 ? utf8 : "<no utf8>");
        return;
    }
    uintptr_t bits = (uintptr_t)held;
    uint32_t value32 = (uint32_t)bits;
    char fourcc[8] = {0};
    if (value32 >= 0x20202020u && value32 <= 0x7e7e7e7eu) {
        fourcc[0] = (char)(value32 >> 24); fourcc[1] = (char)(value32 >> 16);
        fourcc[2] = (char)(value32 >> 8);  fourcc[3] = (char)value32;
    }
    snprintf(out, size, "NUM %ld 0x%08lx %s", (long)bits, (unsigned long)value32,
             fourcc[0] ? fourcc : "-");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "FAIL: no name list was named, so nothing was examined\n");
            return 1;
        }
        gStringClass = object_getClass((__bridge id)(CFStringRef)CFSTR("control"));
        void *handle = dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation",
                              RTLD_LAZY | RTLD_GLOBAL);
        if (handle == NULL) {
            fprintf(stderr, "FAIL: AVFoundation did not load: %s\n", dlerror());
            return 1;
        }

        /* controls */
        char answer[256];
        read_value("AVMediaTypeVideo", "AVMediaTypeVideo", answer, sizeof answer);
        printf("CONTROL\tAVMediaTypeVideo\t%s\n", answer);
        read_value("AVMediaTypeDepthData", "AVMediaTypeDepthData", answer, sizeof answer);
        printf("CONTROL\tAVMediaTypeDepthData\t%s\n", answer);
        read_value("AVMediaTypeCharonProbeNoSuchConstant", "AVMediaTypeCharonProbeNoSuchConstant",
                   answer, sizeof answer);
        printf("CONTROL\tAVMediaTypeCharonProbeNoSuchConstant\t%s\n", answer);
        Class player = objc_getClass("AVPlayer");
        if (player == nil) {
            fprintf(stderr, "FAIL: AVPlayer does not resolve, so AVFoundation was not really loaded\n");
            return 1;
        }
        printf("CONTROL\tAVPlayer\tHAS %p\n", (__bridge void *)player);

        FILE *list = fopen(argv[1], "r");
        if (list == NULL) {
            fprintf(stderr, "FAIL: the name list did not open, so nothing was examined\n");
            return 1;
        }
        unsigned read = 0, rows = 0, agreed = 0;
        char line[512];
        while (fgets(line, sizeof line, list) != NULL) {
            char *save = NULL;
            char *name = strtok_r(line, "\r\n", &save);
            if (name == NULL || name[0] == '\0') {
                continue;
            }
            read++;
            char host[256], port[256], prefixed[512];
            read_value(name, name, host, sizeof host);
            snprintf(prefixed, sizeof prefixed, "charon_host_%s", name);
            read_value(name, prefixed, port, sizeof port);
            /* TAB separated, and it must be: a value is "STR <the string>", which carries spaces of its
           * own, so a space-separated row cannot be split into three fields without cutting the value in
           * half - which is what the first version of the join did, and it reported 60 DIFFERS rows for
           * 116 constants that all agreed. */
            printf("%s\t%s\t%s\n", name, host, port);
            rows++;
            if (strcmp(host, port) == 0) {
                agreed++;
            }
        }
        fclose(list);
        printf("names read: %u  rows: %u  in agreement: %u\n", read, rows, agreed);
        return 0;
    }
}