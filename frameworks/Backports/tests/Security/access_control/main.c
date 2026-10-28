#include <stdio.h>
#include <Security/Security.h>
#include <CoreFoundation/CoreFoundation.h>

static void describe_error(CFErrorRef error)
{
    char domain[128];
    if (!error) {
        printf("error=none");
        return;
    }
    CFStringGetCString(CFErrorGetDomain(error), domain, sizeof domain, kCFStringEncodingUTF8);
    printf("error=%s/%ld", domain, (long)CFErrorGetCode(error));
}

static void create(const char *label, CFTypeRef protection, CFOptionFlags flags)
{
    CFErrorRef error = NULL;
    SecAccessControlRef acl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, protection, flags, &error);
    printf("%s flags=0x%08lx acl=%s ", label, (unsigned long)flags, acl ? "yes" : "NULL");
    describe_error(error);
    printf("\n");
    if (acl)
        CFRelease(acl);
    if (error)
        CFRelease(error);
}

int main(void)
{
    CFTypeRef protections[] = {
        kSecAttrAccessibleWhenUnlocked, kSecAttrAccessibleAfterFirstUnlock, kSecAttrAccessibleAlways,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrAccessibleAlwaysThisDeviceOnly, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    };
    const char *protectionNames[] = {"whenUnlocked", "afterFirstUnlock", "always", "whenUnlockedThisDeviceOnly",
        "afterFirstUnlockThisDeviceOnly", "alwaysThisDeviceOnly", "whenPasscodeSetThisDeviceOnly"};
    CFOptionFlags flags[] = {0, 1u<<0, 1u<<1, 1u<<3, 1u<<4, 1u<<5, 1u<<14, 1u<<15, 1u<<30, 1u<<31,
        (1u<<0)|(1u<<14), (1u<<0)|(1u<<15), (1u<<14)|(1u<<15), (1u<<30)|(1u<<14), (1u<<0)|(1u<<3), (1u<<0)|(1u<<4),
        (1u<<0)|(1u<<1)|(1u<<3), 1u<<20, 1u<<2, (1u<<0)|(1u<<30),
        (1u<<1)|(1u<<3), (1u<<1)|(1u<<4), (1u<<3)|(1u<<4), (1u<<4)|(1u<<5), (1u<<0)|(1u<<5), (1u<<1)|(1u<<5),
        (1u<<1)|(1u<<14), (1u<<4)|(1u<<14), (1u<<3)|(1u<<15), (1u<<31)|(1u<<14), (1u<<31)|(1u<<0), (1u<<31)|(1u<<30),
        (1u<<14)|(1u<<15)|(1u<<30), (1u<<14)|(1u<<1)|(1u<<4), (1u<<0)|(1u<<31)|(1u<<30), (1u<<1)|(1u<<30),
        (1u<<4)|(1u<<30), (1u<<0)|(1u<<14)|(1u<<30), (1u<<2)|(1u<<0), (1u<<20)|(1u<<1), 0x40004000u, 0xc0000000u,
    };
    size_t protectionCount = sizeof protections / sizeof protections[0];
    size_t flagCount = sizeof flags / sizeof flags[0];
    for (size_t p = 0; p < protectionCount; p++) {
        for (size_t f = 0; f < flagCount; f++) {
            char label[96];
            snprintf(label, sizeof label, "%s", protectionNames[p]);
            create(label, protections[p], flags[f]);
        }
    }
    create("bogus", CFSTR("bogus"), 0);
    create("nil", NULL, 0);
    create("number", CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &(int){1}), 0);

    CFErrorRef error = NULL;
    SecAccessControlRef a = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlocked, 1u<<0, &error);
    SecAccessControlRef b = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlocked, 1u<<0, NULL);
    SecAccessControlRef c = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlocked, 1u<<3, NULL);
    SecAccessControlRef d = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAfterFirstUnlock, 1u<<0, NULL);
    char typeName[64];
    CFStringRef typeDescription = CFCopyTypeIDDescription(CFGetTypeID(a));
    CFStringGetCString(typeDescription, typeName, sizeof typeName, kCFStringEncodingUTF8);
    printf("typeid=%s\n", typeName);
    printf("equal same=%d diffflags=%d diffprot=%d\n", CFEqual(a, b), CFEqual(a, c), CFEqual(a, d));
    printf("equal reflexive=%d\n", CFEqual(a, a));
    printf("self-hash-stable=%d\n", CFHash(a) == CFHash(a));
    printf("error-after-success=%s\n", error ? "set" : "none");
    CFRetain(a);
    CFRelease(a);
    CFRelease(a);
    CFRelease(b);
    CFRelease(c);
    CFRelease(d);
    return 0;
}
