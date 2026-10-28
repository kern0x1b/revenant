#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>

static CFMutableDictionaryRef dictionary(void)
{
    return CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static void base(CFMutableDictionaryRef query)
{
    CFDictionarySetValue(query, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(query, kSecAttrService, CFSTR("revenant.gap.items.contract"));
    CFDictionarySetValue(query, kSecAttrAccount, CFSTR("presence"));
}

static void report(const char *label, OSStatus status)
{
    printf("%s status=%d\n", label, (int)status);
}

int main(void)
{
    CFMutableDictionaryRef query = dictionary();
    base(query);
    SecItemDelete(query);
    CFRelease(query);

    CFErrorRef error = NULL;
    SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlocked,
                                                                 kSecAccessControlUserPresence, &error);
    CFMutableDictionaryRef add = dictionary();
    base(add);
    CFDictionarySetValue(add, kSecValueData, CFDataCreate(kCFAllocatorDefault, (const UInt8 *)"guarded", 7));
    CFDictionarySetValue(add, kSecAttrAccessControl, access);
    report("add presence", access ? SecItemAdd(add, NULL) : -1);
    CFRelease(add);

    query = dictionary();
    base(query);
    CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
    CFDictionarySetValue(query, kSecUseNoAuthenticationUI, kCFBooleanTrue);
    CFTypeRef found = NULL;
    report("copy presence no-ui", SecItemCopyMatching(query, &found));
    if (found)
        CFRelease(found);
    CFRelease(query);

    query = dictionary();
    base(query);
    CFMutableDictionaryRef values = dictionary();
    CFDictionarySetValue(values, kSecValueData, CFDataCreate(kCFAllocatorDefault, (const UInt8 *)"changed", 7));
    CFDictionarySetValue(query, kSecUseNoAuthenticationUI, kCFBooleanTrue);
    report("update presence no-ui", SecItemUpdate(query, values));
    CFRelease(values);
    CFRelease(query);

    query = dictionary();
    base(query);
    report("cleanup", SecItemDelete(query));
    CFRelease(query);
    if (access)
        CFRelease(access);
    return 0;
}
