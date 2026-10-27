#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <stdio.h>

static void report_error(const char *label, const char *step, CFErrorRef error)
{
    printf("%s %s error=%ld\n", label, step, error ? (long)CFErrorGetCode(error) : 0L);
    if (error)
        CFRelease(error);
}

static SecKeyRef secure_key(const char *label)
{
    CFErrorRef error = NULL;
    SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                 kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                                 kSecAccessControlPrivateKeyUsage, &error);
    if (!access) {
        report_error(label, "access", error);
        return NULL;
    }
    CFMutableDictionaryRef privateAttributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(privateAttributes, kSecAttrIsPermanent, kCFBooleanFalse);
    CFDictionarySetValue(privateAttributes, kSecAttrAccessControl, access);
    int bitCount = 256;
    CFNumberRef bits = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &bitCount);
    CFMutableDictionaryRef parameters = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(parameters, kSecAttrKeyType, kSecAttrKeyTypeECSECPrimeRandom);
    CFDictionarySetValue(parameters, kSecAttrKeySizeInBits, bits);
    CFDictionarySetValue(parameters, kSecAttrTokenID, kSecAttrTokenIDSecureEnclave);
    CFDictionarySetValue(parameters, kSecPrivateKeyAttrs, privateAttributes);
    error = NULL;
    SecKeyRef key = SecKeyCreateRandomKey(parameters, &error);
    if (key)
        printf("%s create ok\n", label);
    else
        report_error(label, "create", error);
    CFRelease(parameters);
    CFRelease(bits);
    CFRelease(privateAttributes);
    CFRelease(access);
    return key;
}

static void write_file(const char *directory, const char *name, CFDataRef data)
{
    char path[1024];
    snprintf(path, sizeof path, "%s/%s", directory, name);
    FILE *file = fopen(path, "wb");
    if (!file) {
        printf("write %s failed\n", name);
        return;
    }
    fwrite(CFDataGetBytePtr(data), 1, (size_t)CFDataGetLength(data), file);
    fclose(file);
}

static void report_export(const char *label, const char *role, SecKeyRef key)
{
    CFErrorRef error = NULL;
    CFDataRef data = SecKeyCopyExternalRepresentation(key, &error);
    if (data) {
        const UInt8 *bytes = CFDataGetBytePtr(data);
        printf("%s %s export length=%ld prefix=%02x\n", label, role, (long)CFDataGetLength(data), bytes[0]);
        CFRelease(data);
        if (error)
            CFRelease(error);
    } else {
        report_error(label, role, error);
    }
}

int main(int argc, char **argv)
{
    SecKeyRef first = secure_key("first");
    SecKeyRef second = secure_key("second");
    if (!first || !second)
        return 1;
    SecKeyRef firstPublic = SecKeyCopyPublicKey(first);
    SecKeyRef secondPublic = SecKeyCopyPublicKey(second);
    printf("public first=%s second=%s\n", firstPublic ? "ok" : "missing", secondPublic ? "ok" : "missing");
    if (firstPublic)
        report_export("first", "public", firstPublic);
    report_export("first", "private", first);

    const UInt8 message[] = "message";
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, message, sizeof message - 1);
    CFErrorRef error = NULL;
    CFDataRef signature = SecKeyCreateSignature(first, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, data, &error);
    if (signature) {
        printf("sign ok\n");
        if (argc > 1) {
            CFDataRef point = SecKeyCopyExternalRepresentation(firstPublic, NULL);
            write_file(argv[1], "message.bin", data);
            write_file(argv[1], "signature.der", signature);
            if (point) {
                write_file(argv[1], "public.point", point);
                CFRelease(point);
            }
        }
        printf("verify own=%d\n", SecKeyVerifySignature(firstPublic, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, data, signature, NULL));
        printf("verify other=%d\n", SecKeyVerifySignature(secondPublic, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, data, signature, NULL));
        const UInt8 tampered[] = "messagf";
        CFDataRef changed = CFDataCreate(kCFAllocatorDefault, tampered, sizeof tampered - 1);
        printf("verify tampered=%d\n", SecKeyVerifySignature(firstPublic, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, changed, signature, NULL));
        CFRelease(changed);
        CFRelease(signature);
    } else {
        report_error("first", "sign", error);
    }
    error = NULL;

    CFDictionaryRef none = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDataRef forward = SecKeyCopyKeyExchangeResult(first, kSecKeyAlgorithmECDHKeyExchangeStandard, secondPublic, none, &error);
    CFDataRef backward = SecKeyCopyKeyExchangeResult(second, kSecKeyAlgorithmECDHKeyExchangeStandard, firstPublic, none, NULL);
    if (forward && backward) {
        printf("ecdh length=%ld symmetric=%d\n", (long)CFDataGetLength(forward), CFEqual(forward, backward));
    } else {
        report_error("first", "ecdh", error);
    }
    if (forward)
        CFRelease(forward);
    if (backward)
        CFRelease(backward);
    CFRelease(none);
    CFRelease(data);
    CFRelease(firstPublic);
    CFRelease(secondPublic);
    CFRelease(first);
    CFRelease(second);
    return 0;
}
