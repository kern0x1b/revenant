#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

// The SHAPING half of SecKeyCopyAttributes, driven with a dictionary the test builds.
//
// Nothing here touches a keychain: no SecItemAdd, no SecItemCopyMatching, no kSecAttrIsPermanent, no
// identity. The oracle is a value the TEST chose - which is the only oracle available for a function
// whose other half is a keychain, and it is stated in the registry row's effect as well as here.
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
    // the documented keys, and their answers
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
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        int rsaBits = 1024, ecBits = 256;
        CFNumberRef rsa = CFNumberCreate(NULL, kCFNumberIntType, &rsaBits);
        CFNumberRef ec = CFNumberCreate(NULL, kCFNumberIntType, &ecBits);

        // a well formed answer: both documented keys
        const void *okKeys[] = {kSecAttrKeyType, kSecAttrKeySizeInBits};
        const void *okValues[] = {kSecAttrKeyTypeRSA, rsa};
        CFDictionaryRef good = CFDictionaryCreate(kCFAllocatorDefault, okKeys, okValues, 2,
                                                 &kCFTypeDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
        report("rsa-1024", shape(good));

        // the same, for an EC key of the other size
        const void *ecKeys[] = {kSecAttrKeyType, kSecAttrKeySizeInBits};
        const void *ecValues[] = {kSecAttrKeyTypeECSECPrimeRandom, ec};
        CFDictionaryRef ecAttrs = CFDictionaryCreate(kCFAllocatorDefault, ecKeys, ecValues, 2,
                                                    &kCFTypeDictionaryKeyCallBacks,
                                                    &kCFTypeDictionaryValueCallBacks);
        report("ec-256", shape(ecAttrs));

        // a dictionary missing the documented keys
        CFDictionaryRef thin = CFDictionaryCreate(kCFAllocatorDefault, okKeys, okValues, 1,
                                                 &kCFTypeDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
        report("one-key-only", shape(thin));

        // an answer that is not a dictionary at all, which is what a request for data would hand back
        report("not-a-dictionary", shape(CFSTR("a string, which is what a data request returns")));

        CFRelease(good); CFRelease(ecAttrs); CFRelease(thin); CFRelease(rsa); CFRelease(ec);
    }
    return 0;
}
