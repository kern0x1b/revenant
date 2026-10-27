#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <Security/Security.h>
#include <CoreFoundation/CoreFoundation.h>

extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key) __attribute__((weak_import));

static const char rsaTag[] = "revenant.security-gaps.probe.rsa";
static const char ecTag[] = "revenant.security-gaps.probe.ec";
static const char serviceName[] = "revenant.security-gaps.probe";

static CFDataRef bytes_of(const char *text)
{
    return CFDataCreate(kCFAllocatorDefault, (const UInt8 *)text, (CFIndex)strlen(text));
}

static CFMutableDictionaryRef dictionary(void)
{
    return CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static void print_keys(const char *label, CFDictionaryRef values)
{
    if (!values) {
        printf("probe: %s keys: none\n", label);
        return;
    }
    CFIndex count = CFDictionaryGetCount(values);
    const void **keys = malloc((size_t)count * sizeof *keys);
    CFDictionaryGetKeysAndValues(values, keys, NULL);
    printf("probe: %s keys: %ld\n", label, (long)count);
    for (CFIndex index = 0; index < count; index++) {
        char name[160];
        if (CFStringGetCString((CFStringRef)keys[index], name, sizeof name, kCFStringEncodingUTF8))
            printf("probe:   %s\n", name);
    }
    free(keys);
}

static void print_data(const char *label, OSStatus status, CFTypeRef value)
{
    if (status != errSecSuccess || !value || CFGetTypeID(value) != CFDataGetTypeID()) {
        printf("probe: %s status=%d type=%s\n", label, (int)status, value ? "non-data" : "none");
        return;
    }
    CFDataRef data = (CFDataRef)value;
    const UInt8 *bytes = CFDataGetBytePtr(data);
    CFIndex length = CFDataGetLength(data);
    printf("probe: %s status=0 length=%ld head=%02x%02x%02x%02x\n", label, (long)length,
           length > 3 ? bytes[0] : 0, length > 3 ? bytes[1] : 0, length > 3 ? bytes[2] : 0, length > 3 ? bytes[3] : 0);
}

static void probe_private_key(const char *label, const char *tag)
{
    CFDataRef tagData = bytes_of(tag);
    CFMutableDictionaryRef query = dictionary();
    CFDictionarySetValue(query, kSecClass, kSecClassKey);
    CFDictionarySetValue(query, kSecAttrApplicationTag, tagData);
    CFDictionarySetValue(query, kSecAttrKeyClass, kSecAttrKeyClassPrivate);
    CFDictionarySetValue(query, kSecReturnPersistentRef, kCFBooleanTrue);
    CFTypeRef persistent = NULL;
    OSStatus status = SecItemCopyMatching(query, &persistent);
    printf("probe: %s persistent ref status=%d\n", label, (int)status);
    CFRelease(query);
    if (status == errSecSuccess && persistent) {
        CFMutableDictionaryRef data = dictionary();
        CFDictionarySetValue(data, kSecValuePersistentRef, persistent);
        CFDictionarySetValue(data, kSecReturnData, kCFBooleanTrue);
        CFTypeRef value = NULL;
        status = SecItemCopyMatching(data, &value);
        char text[128];
        snprintf(text, sizeof text, "%s data via persistent ref", label);
        print_data(text, status, value);
        if (value)
            CFRelease(value);
        CFRelease(data);
        CFRelease(persistent);
    }

    CFMutableDictionaryRef byKey = dictionary();
    CFDictionarySetValue(byKey, kSecClass, kSecClassKey);
    CFDictionarySetValue(byKey, kSecAttrApplicationTag, tagData);
    CFDictionarySetValue(byKey, kSecAttrKeyClass, kSecAttrKeyClassPrivate);
    CFDictionarySetValue(byKey, kSecReturnData, kCFBooleanTrue);
    CFTypeRef keyData = NULL;
    status = SecItemCopyMatching(byKey, &keyData);
    char keyText[128];
    snprintf(keyText, sizeof keyText, "%s data by key class", label);
    print_data(keyText, status, keyData);
    if (keyData)
        CFRelease(keyData);
    CFRelease(byKey);

    CFMutableDictionaryRef attributes = dictionary();
    CFDictionarySetValue(attributes, kSecClass, kSecClassKey);
    CFDictionarySetValue(attributes, kSecAttrApplicationTag, tagData);
    CFDictionarySetValue(attributes, kSecAttrKeyClass, kSecAttrKeyClassPrivate);
    CFDictionarySetValue(attributes, kSecReturnAttributes, kCFBooleanTrue);
    CFTypeRef found = NULL;
    status = SecItemCopyMatching(attributes, &found);
    printf("probe: %s attributes status=%d\n", label, (int)status);
    if (status == errSecSuccess && found && CFGetTypeID(found) == CFDictionaryGetTypeID())
        print_keys(label, (CFDictionaryRef)found);
    if (found)
        CFRelease(found);
    CFRelease(attributes);
    CFRelease(tagData);
}

static void generate(const char *label, CFTypeRef keyType, int bits, const char *tag)
{
    CFMutableDictionaryRef parameters = dictionary();
    CFDataRef tagData = bytes_of(tag);
    CFNumberRef size = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &bits);
    CFDictionarySetValue(parameters, kSecAttrKeyType, keyType);
    CFDictionarySetValue(parameters, kSecAttrKeySizeInBits, size);
    CFDictionarySetValue(parameters, kSecAttrIsPermanent, kCFBooleanTrue);
    CFDictionarySetValue(parameters, kSecAttrApplicationTag, tagData);
    SecKeyRef publicKey = NULL, privateKey = NULL;
    OSStatus status = SecKeyGeneratePair(parameters, &publicKey, &privateKey);
    printf("probe: %s generate status=%d public=%s private=%s\n", label, (int)status,
           publicKey ? "yes" : "no", privateKey ? "yes" : "no");
    if (privateKey) {
        if (SecKeyCopyAttributeDictionary) {
            CFDictionaryRef attributes = SecKeyCopyAttributeDictionary(privateKey);
            print_keys(label, attributes);
            if (attributes)
                CFRelease(attributes);
        } else {
            printf("probe: %s SecKeyCopyAttributeDictionary absent\n", label);
        }
        CFRelease(privateKey);
    }
    if (publicKey)
        CFRelease(publicKey);
    CFRelease(size);
    CFRelease(tagData);
    CFRelease(parameters);
}

static void add_item(const char *label, CFTypeRef accessible, CFTypeRef control)
{
    CFMutableDictionaryRef item = dictionary();
    CFDataRef service = bytes_of(serviceName);
    CFDataRef secret = bytes_of("probe");
    CFDictionarySetValue(item, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(item, kSecAttrService, CFStringCreateWithCString(kCFAllocatorDefault, serviceName, kCFStringEncodingUTF8));
    CFDictionarySetValue(item, kSecValueData, secret);
    if (accessible)
        CFDictionarySetValue(item, kSecAttrAccessible, accessible);
    if (control)
        CFDictionarySetValue(item, CFSTR("accc"), control);
    OSStatus status = SecItemAdd(item, NULL);
    printf("probe: add %s status=%d\n", label, (int)status);
    if (status == errSecSuccess) {
        CFMutableDictionaryRef remove = dictionary();
        CFDictionarySetValue(remove, kSecClass, kSecClassGenericPassword);
        CFDictionarySetValue(remove, kSecAttrService, CFDictionaryGetValue(item, kSecAttrService));
        printf("probe: delete %s status=%d\n", label, (int)SecItemDelete(remove));
        CFRelease(remove);
    }
    CFRelease(item);
    CFRelease(service);
    CFRelease(secret);
}

static void remove_key(const char *tag)
{
    CFDataRef tagData = bytes_of(tag);
    CFMutableDictionaryRef query = dictionary();
    CFDictionarySetValue(query, kSecClass, kSecClassKey);
    CFDictionarySetValue(query, kSecAttrApplicationTag, tagData);
    OSStatus status = SecItemDelete(query);
    printf("probe: cleanup key %s status=%d\n", tag, (int)status);
    CFRelease(query);
    CFRelease(tagData);
}

static void reachability(void)
{
    CFMutableDictionaryRef query = dictionary();
    CFDictionarySetValue(query, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(query, kSecAttrService, CFSTR("revenant.security-gaps.absent"));
    printf("probe: absent generic lookup status=%d\n", (int)SecItemCopyMatching(query, NULL));
    CFRelease(query);
}

int main(void)
{
    freopen("/var/mobile/Library/Caches/revenant-security-gaps-probe.txt", "w", stdout);
    printf("probe: start\n");
    reachability();
    add_item("always", kSecAttrAccessibleAlways, NULL);
    add_item("after-first-unlock", kSecAttrAccessibleAfterFirstUnlock, NULL);
    remove_key(rsaTag);
    remove_key(ecTag);
    generate("rsa-2048", kSecAttrKeyTypeRSA, 2048, rsaTag);
    probe_private_key("rsa-2048", rsaTag);
    generate("ec-p256", CFSTR("73"), 256, ecTag);
    probe_private_key("ec-p256", ecTag);
    add_item("baseline-accessible", kSecAttrAccessibleWhenUnlockedThisDeviceOnly, NULL);
    add_item("passcode-accessible", CFSTR("aku"), NULL);
    add_item("access-control-key", kSecAttrAccessibleWhenUnlockedThisDeviceOnly, CFDataCreate(kCFAllocatorDefault, (const UInt8 *)"x", 1));
    add_item("token-id-key", kSecAttrAccessibleWhenUnlockedThisDeviceOnly, NULL);
    remove_key(rsaTag);
    remove_key(ecTag);
    printf("probe: done\n");
    return 0;
}
