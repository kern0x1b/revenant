// The host's own SensorKit values, read the way the ImageIO trap says: dlsym on a const
// object-pointer VARIABLE returns the address of the variable, so it is dereferenced ONCE.
//
// Nothing here calls into SensorKit. The library is opened, a symbol is looked up, and the bytes of the
// string the variable holds are printed: no sensor, no reader, no authorization, no device.
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
    for (size_t i = 0; i < sizeof CHaronNames / sizeof CHaronNames[0]; i++) {
        CFStringRef s = *(CFStringRef *)dlsym(lib, CHaronNames[i]);
        char b[256] = {0};
        if (!s) { printf("HOST\t%s\t(NOT EXPORTED)\n", CHaronNames[i]); continue; }
        if (!CFStringGetCString(s, b, sizeof b, kCFStringEncodingUTF8)) {
            printf("HOST\t%s\t(UNREADABLE)\n", CHaronNames[i]);
            continue;
        }
        printf("HOST\t%s\t%s\n", CHaronNames[i], b);
    }
    return 0;
}
