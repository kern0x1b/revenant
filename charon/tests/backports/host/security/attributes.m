#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

CFDictionaryRef CharonSecurityAttributesFromItemResult(CFTypeRef result);

static void report(const char *name, const char *value)
{
    printf("%s\t%s\n", name, value);
}

static const char *shape(CFTypeRef result)
{
    CFDictionaryRef attributes = CharonSecurityAttributesFromItemResult(result);
    if (!attributes)
        return "NULL";
    CFTypeRef type = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    CFTypeRef size = CFDictionaryGetValue(attributes, kSecAttrKeySizeInBits);
    static char out[128];
    const char *typeName = type ? CFStringGetCString((CFStringRef)type, out, sizeof(out),
                                                      kCFStringEncodingUTF8) ? out : "?" : "none";
    int bits = 0;
    if (size)
        CFNumberGetValue((CFNumberRef)size, kCFNumberIntType, &bits);
    snprintf(out, sizeof(out), "%s/%d", typeName, bits);
    return out;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        int rsaBits = 1024, ecBits = 256;
        CFNumberRef rsa = CFNumberCreate(NULL, kCFNumberIntType, &rsaBits);
        CFNumberRef ec = CFNumberCreate(NULL, kCFNumberIntType, &ecBits);

        const void *okKeys[] = {kSecAttrKeyType, kSecAttrKeySizeInBits};
        const void *okValues[] = {kSecAttrKeyTypeRSA, rsa};
        CFDictionaryRef good = CFDictionaryCreate(kCFAllocatorDefault, okKeys, okValues, 2,
                                                 &kCFTypeDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
        report("rsa-1024", shape(good));

        const void *ecKeys[] = {kSecAttrKeyType, kSecAttrKeySizeInBits};
        const void *ecValues[] = {kSecAttrKeyTypeECSECPrimeRandom, ec};
        CFDictionaryRef ecAttrs = CFDictionaryCreate(kCFAllocatorDefault, ecKeys, ecValues, 2,
                                                    &kCFTypeDictionaryKeyCallBacks,
                                                    &kCFTypeDictionaryValueCallBacks);
        report("ec-256", shape(ecAttrs));

        CFDictionaryRef thin = CFDictionaryCreate(kCFAllocatorDefault, okKeys, okValues, 1,
                                                 &kCFTypeDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
        report("one-key-only", shape(thin));

        report("not-a-dictionary", shape(CFSTR("a string, which is what a data request returns")));

        CFRelease(good); CFRelease(ecAttrs); CFRelease(thin); CFRelease(rsa); CFRelease(ec);
    }
    return 0;
}
