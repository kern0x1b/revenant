#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

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
