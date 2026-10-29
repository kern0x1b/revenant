#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>

#if !defined(REVENANT_CORE_GRAPHICS_LIBRARY)
#define REVENANT_CORE_GRAPHICS_LIBRARY "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
#endif

// CGColorSpaceCopyPropertyList is declared from iOS 10, and the iOS 6.1.3 CoreGraphics library exports the function.
// This forwards to that library's own function, so the property list is the system's, not a copy made here. The
// library is opened by path, because the symbol defined in this image would otherwise be found first.
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
