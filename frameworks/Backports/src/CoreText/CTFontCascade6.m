#include "../revenant_font_cascade.h"

static void *revenant_system_core_text(void)
{
    static void *handle = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
    });
    return handle;
}

static CTFontRef revenant_cascaded(CTFontRef made)
{
    CTFontRef result = revenant_cascade_font(made);
    if (made)
        CFRelease(made);
    return result;
}

CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix)
{
    static __typeof__(&CTFontCreateWithName) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTFontCreateWithName))dlsym(revenant_system_core_text(), "CTFontCreateWithName");
    });
    return revenant_cascaded(system(name, size, matrix));
}

CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef descriptor, CGFloat size, const CGAffineTransform *matrix)
{
    static __typeof__(&CTFontCreateWithFontDescriptor) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTFontCreateWithFontDescriptor))dlsym(revenant_system_core_text(), "CTFontCreateWithFontDescriptor");
    });
    return revenant_cascaded(system(descriptor, size, matrix));
}

CTFontRef CTFontCreateCopyWithAttributes(CTFontRef font, CGFloat size, const CGAffineTransform *matrix, CTFontDescriptorRef attributes)
{
    static __typeof__(&CTFontCreateCopyWithAttributes) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTFontCreateCopyWithAttributes))dlsym(revenant_system_core_text(), "CTFontCreateCopyWithAttributes");
    });
    return revenant_cascaded(system(font, size, matrix, attributes));
}

CTFontRef CTFontCreateCopyWithSymbolicTraits(CTFontRef font, CGFloat size, const CGAffineTransform *matrix, CTFontSymbolicTraits symTraitValue, CTFontSymbolicTraits symTraitMask)
{
    static __typeof__(&CTFontCreateCopyWithSymbolicTraits) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTFontCreateCopyWithSymbolicTraits))dlsym(revenant_system_core_text(), "CTFontCreateCopyWithSymbolicTraits");
    });
    return revenant_cascaded(system(font, size, matrix, symTraitValue, symTraitMask));
}

CTFontRef CTFontCreateCopyWithFamily(CTFontRef font, CGFloat size, const CGAffineTransform *matrix, CFStringRef family)
{
    static __typeof__(&CTFontCreateCopyWithFamily) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTFontCreateCopyWithFamily))dlsym(revenant_system_core_text(), "CTFontCreateCopyWithFamily");
    });
    return revenant_cascaded(system(font, size, matrix, family));
}

CTFontRef CTFontCreateUIFontForLanguage(CTFontUIFontType uiType, CGFloat size, CFStringRef language)
{
    static __typeof__(&CTFontCreateUIFontForLanguage) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTFontCreateUIFontForLanguage))dlsym(revenant_system_core_text(), "CTFontCreateUIFontForLanguage");
    });
    return revenant_cascaded(system(uiType, size, language));
}

CTFontRef CTFontCreateWithGraphicsFont(CGFontRef graphicsFont, CGFloat size, const CGAffineTransform *matrix, CTFontDescriptorRef attributes)
{
    static __typeof__(&CTFontCreateWithGraphicsFont) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTFontCreateWithGraphicsFont))dlsym(revenant_system_core_text(), "CTFontCreateWithGraphicsFont");
    });
    return revenant_cascaded(system(graphicsFont, size, matrix, attributes));
}
