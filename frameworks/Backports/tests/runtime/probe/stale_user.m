#import <objc/runtime.h>

// Strong references to the class and its metaclass, bound by name to the library this probe was linked against.
extern char OBJC_CLASS_$_AVSampleBufferDisplayLayer;
extern char OBJC_METACLASS_$_AVSampleBufferDisplayLayer;

Class revenant_stale_user_class(void)
{
    return (Class)&OBJC_CLASS_$_AVSampleBufferDisplayLayer;
}

Class revenant_stale_user_metaclass(void)
{
    return (Class)&OBJC_METACLASS_$_AVSampleBufferDisplayLayer;
}
