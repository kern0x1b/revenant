#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <malloc/malloc.h>
#include "../revenant_font_cascade.h"

// The CTFont a UICFFont holds sits at offset 0x30 of the object (GraphicsServices' GSFontGetCTFont reads it there).
// That is a layout of iOS 6.1.3, read from the process and not declared anywhere, so the slot is written only for
// an instance of exactly the class and sizes measured there (class UICFFont, class_getInstanceSize 4, so the object
// is a UIFont whose storage GraphicsServices allocates itself, malloc_size 64); any other build leaves the font as
// the system made it.
static const size_t revenant_gs_font_core_text_offset = 0x30;
static const size_t revenant_gs_font_instance_size = 4;
static const size_t revenant_gs_font_allocation_size = 64;

static CTFontRef revenant_core_text_font_of(UIFont *font)
{
    SEL selector = @selector(ctFontRef);
    if (![font respondsToSelector:selector])
        return NULL;
    return ((CTFontRef (*)(id, SEL))objc_msgSend)(font, selector);
}

static BOOL revenant_slot_is_known_layout(UIFont *font)
{
    Class cls = object_getClass(font);
    static Class measured;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        measured = objc_getClass("UICFFont");
    });
    return measured != Nil && cls == measured && class_getInstanceSize(cls) == revenant_gs_font_instance_size
        && malloc_size((__bridge const void *)font) == revenant_gs_font_allocation_size;
}

static UIFont *revenant_cascaded_font(UIFont *font)
{
    if (font == nil || !revenant_slot_is_known_layout(font))
        return font;
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    CTFontRef current = revenant_core_text_font_of(font);
    if (current == NULL)
        return font;
    void **slot = (void **)((char *)(__bridge void *)font + revenant_gs_font_core_text_offset);
    pthread_mutex_lock(&lock);
    if (*slot == (void *)current) {
        CTFontRef made = revenant_cascade_font(current);
        if (made != NULL && made != current) {
            *slot = (void *)made;
            CFRelease(current);
        } else if (made != NULL) {
            CFRelease(made);
        }
    }
    pthread_mutex_unlock(&lock);
    return font;
}

@interface RevenantFontCascadeInstaller : NSObject
@end

@implementation RevenantFontCascadeInstaller

+ (void)load
{
    if (!revenant_cascade_applies())
        return;
    Class metaclass = object_getClass([UIFont class]);

    SEL named = @selector(fontWithName:size:);
    Method namedMethod = class_getClassMethod([UIFont class], named);
    if (namedMethod) {
        UIFont *(*namedOriginal)(id, SEL, NSString *, CGFloat) = (UIFont *(*)(id, SEL, NSString *, CGFloat))method_getImplementation(namedMethod);
        class_replaceMethod(metaclass, named, imp_implementationWithBlock(^UIFont *(id self, NSString *name, CGFloat size) {
            return revenant_cascaded_font(namedOriginal(self, named, name, size));
        }), method_getTypeEncoding(namedMethod));
    }

    SEL sizes[] = {@selector(systemFontOfSize:), @selector(boldSystemFontOfSize:), @selector(italicSystemFontOfSize:)};
    for (unsigned index = 0; index < sizeof sizes / sizeof sizes[0]; index++) {
        SEL selector = sizes[index];
        Method method = class_getClassMethod([UIFont class], selector);
        if (method == NULL)
            continue;
        UIFont *(*original)(id, SEL, CGFloat) = (UIFont *(*)(id, SEL, CGFloat))method_getImplementation(method);
        class_replaceMethod(metaclass, selector, imp_implementationWithBlock(^UIFont *(id self, CGFloat size) {
            return revenant_cascaded_font(original(self, selector, size));
        }), method_getTypeEncoding(method));
    }

    SEL resize = @selector(fontWithSize:);
    Class concretes[] = {[UIFont class], objc_getClass("UICFFont")};
    for (unsigned index = 0; index < sizeof concretes / sizeof concretes[0]; index++) {
        Class concrete = concretes[index];
        if (concrete == Nil)
            continue;
        Method resizeMethod = class_getInstanceMethod(concrete, resize);
        Class parent = class_getSuperclass(concrete);
        if (resizeMethod == NULL || (index > 0 && parent && class_getInstanceMethod(parent, resize) == resizeMethod))
            continue;
        UIFont *(*resizeOriginal)(id, SEL, CGFloat) = (UIFont *(*)(id, SEL, CGFloat))method_getImplementation(resizeMethod);
        class_replaceMethod(concrete, resize, imp_implementationWithBlock(^UIFont *(UIFont *self, CGFloat size) {
            return revenant_cascaded_font(resizeOriginal(self, resize, size));
        }), method_getTypeEncoding(resizeMethod));
    }
}

@end
