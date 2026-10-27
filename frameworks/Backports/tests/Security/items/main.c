#include <stdio.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>

static CFMutableDictionaryRef dictionary(void)
{
    return CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static void base(CFMutableDictionaryRef query)
{
    CFDictionarySetValue(query, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(query, kSecAttrService, CFSTR("revenant.gap.items.parity"));
    CFDictionarySetValue(query, kSecAttrAccount, CFSTR("parity"));
}

static CFDataRef bytes(const char *text)
{
    return CFDataCreate(kCFAllocatorDefault, (const UInt8 *)text, (CFIndex)strlen(text));
}

static void report(const char *label, OSStatus status)
{
    printf("%s status=%d\n", label, (int)status);
}

static void report_value(const char *label, CFTypeRef value)
{
    if (!value) {
        printf("%s value=none\n", label);
        return;
    }
    if (CFGetTypeID(value) == CFDataGetTypeID()) {
        CFDataRef data = (CFDataRef)value;
        printf("%s data=%.*s\n", label, (int)CFDataGetLength(data), (const char *)CFDataGetBytePtr(data));
        return;
    }
    printf("%s value=other\n", label);
}

static void report_constant(const char *label, CFStringRef constant)
{
    char buffer[128];
    if (constant && CFStringGetCString(constant, buffer, sizeof buffer, kCFStringEncodingUTF8))
        printf("const %s = %s\n", label, buffer);
    else
        printf("const %s = none\n", label);
}

int main(void)
{
    report_constant("kSecUseNoAuthenticationUI", kSecUseNoAuthenticationUI);
    report_constant("kSecUseOperationPrompt", kSecUseOperationPrompt);

    CFMutableDictionaryRef query = dictionary();
    base(query);
    report("cleanup", SecItemDelete(query));
    CFRelease(query);

    CFMutableDictionaryRef add = dictionary();
    base(add);
    CFDictionarySetValue(add, kSecValueData, bytes("one"));
    report("add", SecItemAdd(add, NULL));
    report("add again", SecItemAdd(add, NULL));
    CFRelease(add);

    query = dictionary();
    base(query);
    CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
    CFTypeRef found = NULL;
    report("copy data", SecItemCopyMatching(query, &found));
    report_value("copy data", found);
    if (found)
        CFRelease(found);
    CFDictionarySetValue(query, kSecUseNoAuthenticationUI, kCFBooleanTrue);
    found = NULL;
    report("copy no-ui", SecItemCopyMatching(query, &found));
    report_value("copy no-ui", found);
    if (found)
        CFRelease(found);
    CFRelease(query);

    query = dictionary();
    base(query);
    CFDictionarySetValue(query, kSecReturnPersistentRef, kCFBooleanTrue);
    found = NULL;
    report("copy persistent", SecItemCopyMatching(query, &found));
    printf("copy persistent present=%d\n", found != NULL);
    if (found)
        CFRelease(found);
    CFRelease(query);

    query = dictionary();
    base(query);
    CFMutableDictionaryRef values = dictionary();
    CFDictionarySetValue(values, kSecValueData, bytes("two"));
    report("update", SecItemUpdate(query, values));
    CFDictionarySetValue(query, kSecUseNoAuthenticationUI, kCFBooleanTrue);
    report("update no-ui", SecItemUpdate(query, values));
    CFRelease(values);
    CFRelease(query);

    query = dictionary();
    base(query);
    CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
    found = NULL;
    report("copy after update", SecItemCopyMatching(query, &found));
    report_value("copy after update", found);
    if (found)
        CFRelease(found);
    CFRelease(query);

    query = dictionary();
    base(query);
    CFDictionarySetValue(query, kSecUseNoAuthenticationUI, kCFBooleanTrue);
    report("delete no-ui", SecItemDelete(query));
    CFRelease(query);

    query = dictionary();
    base(query);
    CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
    found = NULL;
    report("copy after delete", SecItemCopyMatching(query, &found));
    report_value("copy after delete", found);
    if (found)
        CFRelease(found);
    CFRelease(query);

    query = dictionary();
    base(query);
    report("delete missing", SecItemDelete(query));
    CFRelease(query);

    CFMutableDictionaryRef persistent = dictionary();
    base(persistent);
    CFDictionarySetValue(persistent, kSecValueData, bytes("three"));
    CFDictionarySetValue(persistent, kSecReturnPersistentRef, kCFBooleanTrue);
    found = NULL;
    report("add persistent", SecItemAdd(persistent, &found));
    printf("add persistent returned=%d\n", found != NULL);
    if (found)
        CFRelease(found);
    CFRelease(persistent);

    query = dictionary();
    base(query);
    report("cleanup end", SecItemDelete(query));
    CFRelease(query);
    return 0;
}
