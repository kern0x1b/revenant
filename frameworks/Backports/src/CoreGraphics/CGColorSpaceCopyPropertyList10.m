#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>

#if !defined(REVENANT_CORE_GRAPHICS_LIBRARY)
#define REVENANT_CORE_GRAPHICS_LIBRARY "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
#endif

CFPropertyListRef CGColorSpaceCopyPropertyList(CGColorSpaceRef space)
{
    static CFPropertyListRef (*function)(CGColorSpaceRef);
    if (!function) {
        static void *library;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            library = dlopen(REVENANT_CORE_GRAPHICS_LIBRARY, RTLD_LAZY);
            if (!library) {
                NSLog(@"CoreGraphics: the system library cannot be opened: %s", dlerror());
                abort();
            }
        });
        function = (CFPropertyListRef (*)(CGColorSpaceRef))dlsym(library, "CGColorSpaceCopyPropertyList");
        if (!function) {
            NSLog(@"CoreGraphics: the system library does not export CGColorSpaceCopyPropertyList");
            abort();
        }
    }
    return function(space);
}
