#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>
#import <unistd.h>

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        static const unsigned char material[128] = {
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
            0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
            0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
            0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
            0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
            0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f,
            0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
            0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5e, 0x5f,
            0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
            0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f,
            0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
            0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x7f,
        };
        CFDataRef data = CFDataCreate(kCFAllocatorDefault, material, (CFIndex)sizeof(material));
        int keySize = 1024;
        CFNumberRef bits = CFNumberCreate(NULL, kCFNumberIntType, &keySize);
        CFStringRef tag = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
                                                  CFSTR("charon-keyref-lifetime-%d"), (int)getpid());

        const void *keys[] = {kSecClass, kSecValueData, kSecAttrKeyType, kSecAttrKeySizeInBits,
                              kSecAttrApplicationTag, kSecReturnRef};
        const void *values[] = {kSecClassKey, data, kSecAttrKeyTypeRSA, bits, tag, kCFBooleanTrue};
        CFDictionaryRef add = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 6,
                                                 &kCFTypeDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
        CFTypeRef ref = NULL;
        OSStatus added = SecItemAdd(add, &ref);
        printf("SecItemAdd: %d, ref %s\n", (int)added, ref ? "handed back" : "none");

        if (added == errSecSuccess && ref) {
            unsigned char digest[20] = {0};
            size_t sigLen = 512;
            unsigned char sig[512] = {0};
            OSStatus sign1 = SecKeyRawSign((SecKeyRef)ref, kSecPaddingPKCS1SHA1, digest,
                                            sizeof(digest), sig, &sigLen);
            printf("SecKeyRawSign WHILE the item exists: %d (%zu bytes)\n", (int)sign1, sigLen);

            const void *delKeys[] = {kSecClass, kSecAttrApplicationTag};
            const void *delValues[] = {kSecClassKey, tag};
            CFDictionaryRef del = CFDictionaryCreate(kCFAllocatorDefault, delKeys, delValues, 2,
                                                     &kCFTypeDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
            OSStatus deleted = SecItemDelete(del);
            printf("SecItemDelete: %d\n", (int)deleted);

            sigLen = sizeof(sig);
            OSStatus sign2 = SecKeyRawSign((SecKeyRef)ref, kSecPaddingPKCS1SHA1, digest,
                                            sizeof(digest), sig, &sigLen);
            printf("SecKeyRawSign AFTER the item is deleted: %d\n", (int)sign2);
            if (sign2 == errSecSuccess) {
                sigLen = sizeof(sig);
                OSStatus verified = SecKeyRawVerify((SecKeyRef)ref, kSecPaddingPKCS1SHA1, digest,
                                                    sizeof(digest), sig, sigLen);
                printf("SecKeyRawVerify after the delete: %d\n", (int)verified);
            }
            printf("THE ANSWER IS THE LINE ABOVE: 0 means the ref still works, and the port may add and "
                   "delete immediately.\n");
            printf("block size before %zu after %zu\n", SecKeyGetBlockSize((SecKeyRef)ref),
                   SecKeyGetBlockSize((SecKeyRef)ref));
            CFRelease(del);
        }
        CFRelease(add);
        if (ref)
            CFRelease(ref);
        if (bits)
            CFRelease(bits);
        if (data)
            CFRelease(data);
        if (tag)
            CFRelease(tag);
    }
    return 0;
}
