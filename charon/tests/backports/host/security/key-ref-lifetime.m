// key-ref-lifetime.m — the measurement that decides how SecKeyCreateWithData may build a key.
//
// NOT RUN YET, and it belongs to the 6.1.3 GUEST: it ADDS a keychain item and DELETES it again, and
// that must never happen to a developer's own keychain. Never a phone, never this Mac.
//
// THE QUESTION, and it is the whole of the port's design for that function. On iOS 6.1.3 a SecKeyRef
// exists only through the keychain: there is no in-memory import, so a port carrying
// SecKeyCreateWithData has to add an item and take the ref the release hands back. Then:
//   does the ref still WORK after its item is deleted?
//     YES  the port adds and deletes immediately, and leaves no persistent state at all
//     NO   the ref is only valid while the item exists, so the port keeps a transient item per process and
//          deletes every port-tagged item at the next call and at exit - documented in the row, because a
//          CF type cannot have cleanup attached to its lifetime
//
// IT USES THE RELEASE'S OWN CALLS, and that is the design constraint, not a preference: on the 6.1.3 guest
// SecKeyCreateSignature and the kSecKeyAlgorithm* constants DO NOT EXIST, so a program that measured the
// guest with the 10.0 API could not run there at all. The four shapes below are copied from the SDK's
// Security.framework/Headers/SecKey.h, grepped before they were written.
//
// THE PORT NOW CARRIES SecKeyCreateSignature AND THE kSecKeyAlgorithm* NAMES, so the clause above is
// history and this file's design constraint is still the design constraint: what it measures - how
// SecKeyCreateWithData may build a key, which is a question about the release's keychain and not about
// the port - is asked through the release's own calls, because the answer has to be the release's. What
// the port does with the four functions is facts/Security/SecKey.md and
// facts/Security/SecKeyElliptic.md, and the 16-cell matrix over them was
// tests/backports/host/seckeycurve/mutate-cells.lua, which seckeycurve/run.sh runs.
//
//   662  OSStatus SecKeyRawSign(SecKeyRef key, SecPadding padding, const uint8_t *dataToSign,
//                                size_t dataToSignLen, uint8_t *sig, size_t *sigLen)
//   692  OSStatus SecKeyRawVerify(SecKeyRef key, SecPadding padding, const uint8_t *signedData,
//                                  size_t signedDataLen, const uint8_t *sig, size_t sigLen)
//   726  OSStatus SecKeyEncrypt(SecKeyRef key, SecPadding padding, const uint8_t *plainText,
//                               size_t plainTextLen, uint8_t *cipherText, size_t *cipherTextLen)
//   839  size_t SecKeyGetBlockSize(SecKeyRef key)
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>
#import <unistd.h>

int main(void)
{
    // UNBUFFERED, so output SURVIVES A CRASH. A mutant that segfaults mid-case would otherwise lose
    // every row printed before it, and the comparator would then say those rows "did not measure" and
    // name a truncated buffer instead of the crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        // 1024 bits of a fixed pattern, so the signature below is over known data
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
        int keySize = 1024;                       // an int local, so CFNumberCreate has a real pointer
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
            unsigned char digest[20] = {0};          // SHA-1 sized, for kSecPaddingPKCS1SHA1
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
