#include "../revenant_impl.h"
#import "../RevenantCFRuntime.h"

__attribute__((visibility("default"))) const void *BACKPORT_IMPL(__kCFBooleanTrue);
__attribute__((visibility("default"))) const void *BACKPORT_IMPL(__kCFBooleanFalse);

__attribute__((constructor)) static void revenant_cfboolean_constants(void)
{
    static const RevenantCFRuntimeClass booleanClass = {
        .version = 0,
        .className = "RevenantCFBoolean",
    };
    CFTypeID typeID = _CFRuntimeRegisterClass(&booleanClass);
    __kCFBooleanTrue = (const void *)CFRetain(_CFRuntimeCreateInstance(NULL, typeID, 0, NULL));
    __kCFBooleanFalse = (const void *)CFRetain(_CFRuntimeCreateInstance(NULL, typeID, 0, NULL));
}
