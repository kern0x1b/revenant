#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <stdio.h>
#include "names.txt"

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    void *cf = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY);
    CFAllocatorRef control = cf ? *(CFAllocatorRef *)dlsym(cf, "kCFAllocatorDefault") : NULL;
    printf("CONTROL\tkCFAllocatorDefault\t%s\n",
           control == kCFAllocatorDefault ? "matches the host's own symbol" : "DIFFERS");
    void *lib = dlopen("/System/Library/Frameworks/SensorKit.framework/SensorKit", RTLD_LAZY);
    if (!lib) { printf("SKIP\tthe host has no SensorKit\n"); return 2; }
    for (size_t i = 0; i < sizeof CRevenantNames / sizeof CRevenantNames[0]; i++) {
        CFStringRef s = *(CFStringRef *)dlsym(lib, CRevenantNames[i]);
        char b[256] = {0};
        if (!s) { printf("HOST\t%s\t(NOT EXPORTED)\n", CRevenantNames[i]); continue; }
        if (!CFStringGetCString(s, b, sizeof b, kCFStringEncodingUTF8)) {
            printf("HOST\t%s\t(UNREADABLE)\n", CRevenantNames[i]);
            continue;
        }
        printf("HOST\t%s\t%s\n", CRevenantNames[i], b);
    }
    return 0;
}
