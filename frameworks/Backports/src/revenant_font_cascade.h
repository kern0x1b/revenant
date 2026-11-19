#ifndef REVENANT_FONT_CASCADE_H
#define REVENANT_FONT_CASCADE_H

#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <pthread.h>

typedef CTFontRef (*RevenantCopyWithAttributesFunction)(CTFontRef, CGFloat, const CGAffineTransform *, CTFontDescriptorRef);

static pthread_mutex_t revenant_cascade_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t revenant_cascade_once = PTHREAD_ONCE_INIT;
static RevenantCopyWithAttributesFunction revenant_cascade_system_copy = NULL;
static CFMutableDictionaryRef revenant_cascade_carriers = NULL;

static void revenant_cascade_resolve(void)
{
    void *coreText = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
    if (coreText)
        revenant_cascade_system_copy = (RevenantCopyWithAttributesFunction)dlsym(coreText, "CTFontCreateCopyWithAttributes");
    revenant_cascade_carriers = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static BOOL revenant_cascade_applies(void)
{
    return NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_0;
}

static BOOL revenant_cascade_ends_in_last_resort(CFArrayRef list)
{
    CFIndex count = CFArrayGetCount(list);
    if (count == 0)
        return NO;
    CTFontDescriptorRef last = (CTFontDescriptorRef)CFArrayGetValueAtIndex(list, count - 1);
    CFTypeRef name = CTFontDescriptorCopyAttribute(last, kCTFontNameAttribute);
    BOOL found = name != NULL && CFGetTypeID(name) == CFStringGetTypeID() && CFEqual(name, CFSTR("LastResort"));
    if (name)
        CFRelease(name);
    return found;
}

static CTFontDescriptorRef revenant_cascade_carrier_for(CFArrayRef list)
{
    const void *keys[] = {kCTFontCascadeListAttribute};
    const void *values[] = {list};
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CTFontDescriptorRef carrier = CTFontDescriptorCreateWithAttributes(attributes);
    CFRelease(attributes);
    return carrier;
}

static void revenant_cascade_append_last_resort(CFMutableArrayRef list)
{
    CTFontDescriptorRef lastResort = CTFontDescriptorCreateWithNameAndSize(CFSTR("LastResort"), 17.0);
    CFArrayAppendValue(list, lastResort);
    CFRelease(lastResort);
}

static CTFontDescriptorRef revenant_cascade_default_carrier(CTFontRef font)
{
    CFStringRef key = CTFontCopyPostScriptName(font);
    CTFontDescriptorRef cached = NULL;
    if (key) {
        pthread_mutex_lock(&revenant_cascade_lock);
        cached = (CTFontDescriptorRef)CFDictionaryGetValue(revenant_cascade_carriers, key);
        if (cached)
            CFRetain(cached);
        pthread_mutex_unlock(&revenant_cascade_lock);
        if (cached) {
            CFRelease(key);
            return cached;
        }
    }
    CFArrayRef defaults = CTFontCopyDefaultCascadeListForLanguages(font, NULL);
    CTFontDescriptorRef carrier = NULL;
    if (defaults && CFArrayGetCount(defaults) > 0) {
        CFMutableArrayRef list = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, defaults);
        revenant_cascade_append_last_resort(list);
        carrier = revenant_cascade_carrier_for(list);
        CFRelease(list);
    }
    if (defaults)
        CFRelease(defaults);
    if (key) {
        if (carrier) {
            pthread_mutex_lock(&revenant_cascade_lock);
            CFDictionarySetValue(revenant_cascade_carriers, key, carrier);
            pthread_mutex_unlock(&revenant_cascade_lock);
        }
        CFRelease(key);
    }
    return carrier;
}

static CTFontRef revenant_cascade_font(CTFontRef font)
{
    if (font == NULL)
        return NULL;
    if (!revenant_cascade_applies())
        return (CTFontRef)CFRetain(font);
    pthread_once(&revenant_cascade_once, revenant_cascade_resolve);
    if (revenant_cascade_system_copy == NULL)
        return (CTFontRef)CFRetain(font);

    CTFontDescriptorRef carrier = NULL;
    CFTypeRef current = CTFontCopyAttribute(font, kCTFontCascadeListAttribute);
    if (current && CFGetTypeID(current) == CFArrayGetTypeID()) {
        if (revenant_cascade_ends_in_last_resort((CFArrayRef)current)) {
            CFRelease(current);
            return (CTFontRef)CFRetain(font);
        }
        CFMutableArrayRef list = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, (CFArrayRef)current);
        revenant_cascade_append_last_resort(list);
        carrier = revenant_cascade_carrier_for(list);
        CFRelease(list);
    } else {
        carrier = revenant_cascade_default_carrier(font);
    }
    if (current)
        CFRelease(current);
    if (carrier == NULL)
        return (CTFontRef)CFRetain(font);

    CGAffineTransform matrix = CTFontGetMatrix(font);
    CTFontRef made = revenant_cascade_system_copy(font, CTFontGetSize(font), &matrix, carrier);
    CFRelease(carrier);
    if (made == NULL)
        return (CTFontRef)CFRetain(font);

    return made;
}

#endif
