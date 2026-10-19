#include <dlfcn.h>
#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>
int main(void) {
    void *h = dlopen("/System/Library/Frameworks/ModelIO.framework/ModelIO", RTLD_LAZY | RTLD_LOCAL);
    if (!h) { printf("dlopen failed: %s\n", dlerror()); return 1; }
    const char *names[] = {"kUTTypeAlembic","kUTType3dObject","kUTTypePolygon","kUTTypeStereolithography",
                           "kUTTypeUniversalSceneDescription","kUTTypeUniversalSceneDescriptionMobile", NULL};
    char buf[256];
    for (int i = 0; names[i]; i++) {
        void *sym = dlsym(h, names[i]);
        if (!sym) { printf("%-46s ABSENT\n", names[i]); continue; }
        CFStringRef s = *(CFStringRef const *)sym;
        if (CFGetTypeID(s) != CFStringGetTypeID()) { printf("%-46s not a CFString (type %ld)\n", names[i], (long)CFGetTypeID(s)); continue; }
        if (!CFStringGetCString(s, buf, sizeof buf, kCFStringEncodingUTF8)) { printf("%-46s <unreadable>\n", names[i]); continue; }
        printf("%-46s %s\n", names[i], buf);
    }
    return 0;
}
