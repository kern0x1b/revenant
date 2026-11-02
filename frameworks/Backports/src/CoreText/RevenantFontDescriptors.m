#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

// CTFontManagerCreateFontDescriptorsFromURL is iOS 7. This is the iOS 6 reading of the same question: the
// font descriptors of the font in the file at url, one per font, from the first font of the file. A file with
// several fonts in a collection gives its first font only. Returns a retained array, or NULL when the file is
// not a font. Swift reaches it through @_silgen_name, so the SDK declaration with its availability is not used.
__attribute__((visibility("default")))
CFArrayRef revenant_CTFontManagerCreateFontDescriptorsFromURL(CFURLRef url)
{
    if (url == NULL) {
        return NULL;
    }
    CGDataProviderRef provider = CGDataProviderCreateWithURL(url);
    if (provider == NULL) {
        return NULL;
    }
    CGFontRef font = CGFontCreateWithDataProvider(provider);
    CGDataProviderRelease(provider);
    if (font == NULL) {
        return NULL;
    }
    CTFontRef ctFont = CTFontCreateWithGraphicsFont(font, 0.0, NULL, NULL);
    CGFontRelease(font);
    if (ctFont == NULL) {
        return NULL;
    }
    CTFontDescriptorRef descriptor = CTFontCopyFontDescriptor(ctFont);
    CFRelease(ctFont);
    if (descriptor == NULL) {
        return NULL;
    }
    CFArrayRef descriptors = CFArrayCreate(kCFAllocatorDefault, (const void **)&descriptor, 1, &kCFTypeArrayCallBacks);
    CFRelease(descriptor);
    return descriptors;
}
