// port-shims.h - what the host does not declare, so the port's own two Security files can be
// compiled and run against the host's Security in a differential.
//
// The port reaches four things of the release that no SDK declares, and answers them here from the
// host's own Security so the port's code runs unmodified against a real key:
//
//   * SecKeyRawSign and SecKeyRawVerify become SecKeyCreateSignature and SecKeyVerifySignature with
//     the ECDSA-with-SHA-256 algorithm - which is what the release's own raw call does for a key of its
//     keychain, and the host's real signature and verification underneath.
//   * SecKeyCopyPublicBytes answers a SubjectPublicKeyInfo the way the release serialises one, so the
//     port's own DER reading runs and is not replaced by a convenient shape.
//   * SecKeyCopyAttributeDictionary answers the marker a key of the PORT'S OWN KIND carries, beside the
//     32 private-scalar bytes, and the host's own attributes for every other key - which is how the
//     port sees a key of the release's keychain and takes the release's path instead of the curve.
//   * SecItemCopyMatching, the release's keychain, answers the class a key of the release's keychain
//     carries, because an in-memory key is in no keychain and the host says errSecItemNotFound (-25300)
//     for every key this differential makes. That is measured, and it is why the release-key path
//     needed an answer here at all.
//
// THE DEFINITIONS OF THE LAST TWO ARE NOT IN THIS HEADER, they are in port-shims-impl.m, and the reason
// is the same class of defect as the one the 6.1.3 gate found in the port: both of the port's files
// include this header, so a non-static definition here is defined twice and the link says
// "duplicate symbol". One definition, in one file.
//
// Why the registration exists at all. SecKeyElliptic10.m tells the two kinds of key apart by one
// attribute: kCharonSecKeyScalar, beside the 32 byte kSecValueData of the private scalar, is what a key
// the port made would carry, and only SecKeyCreateWithData - the one entry point of that family the port
// has not written - would put it there. Without a registration a host differential cannot hand the port
// a key of its own kind, and the whole of its curve path went unexecuted: a mutant that returned half
// the DER from the curve's own signing left the run byte-identical.
//
// The two spellings of the attribute key - this string and the port's #define - cannot be checked here,
// because the port's .m is a separate translation unit that never sees this header. They are not needed
// to be: if the two ever part company, the port stops recognising its own keys, takes the release's path
// for them, and the checks that name the curve's own signature and exchange fail. The run is the check.
//
// No keychain, no kSecAttrIsPermanent, no SecItem* call against a real keychain: every key the
// differential registers is one the host made in memory, and it dies with the process.

#ifndef PORT_SHIMS_H
#define PORT_SHIMS_H

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <string.h>

// What the harness can say about a key, and the three names the port's files are compiled with -D
// against. The port's own SecKeyCopyAttributes is NOT one of them: it is the port's definition and it is
// what answers, which is the point of this suite. Only the facility under it is the host's.
extern void CharonShimMarkPortKey(SecKeyRef privateKey, const uint8_t *scalar, size_t length);
extern void CharonShimMarkPortPublicKey(SecKeyRef publicKey);
extern void CharonShimMarkReleaseKey(SecKeyRef key, CFStringRef type);
extern OSStatus charonHost_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result);
extern CFDictionaryRef charonHost_SecKeyCopyAttributeDictionary(SecKeyRef key);

// The two the harness owns, and the -D renames that point the port's calls at them. The other three the
// port reaches - SecKeyRawSign, SecKeyRawVerify, SecKeyCopyPublicBytes, and with them
// SecKeyGetAlgorithmID and SecKeyCreateFromPublicData - are declared and defined in this header itself,
// as static functions, because they are pure functions of the host and carry no state between the two of
// the port's files that include this header.
extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);

// The attribute SecKeyElliptic10.m tells a key of the port's own kind by, spelled here because the
// harness has to answer SecKeyCopyAttributeDictionary and the port's translation unit never sees this
// header. The header's own comment above says why the run, and not this header, is what proves the two
// spellings agree.
#define CHARON_SHIM_SECKEY_MARKER "CharonSecKeyScalar"

// The SubjectPublicKeyInfo of an EC public key, which is what the release's SecKeyCopyPublicBytes gives:
// a SEQUENCE of an AlgorithmIdentifier of the prime256v1 OIDs and a BIT STRING holding the point.
static const uint8_t CharonShimSubjectPublicKeyInfo[] = {
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08,
    0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00};

// The host's own two functions are reached by name through dlsym, not by calling them: the
// differential renames the port's SecKeyCreateSignature and SecKeyVerifySignature to
// charonHost_SecKeyCreateSignature and charonHost_SecKeyVerifySignature with -D, and a -D renames
// every mention of the name in this header too - so a direct call here becomes a call back into the
// port, which calls the shim again, and the recursion ends on the stack guard page. The string in
// dlsym is not a mention, so the host's function is the one that is found.
// WHICH ALGORITHM THE HOST IS ASKED FOR, decided by the PADDING - and the padding is the only thing
// the release's raw call carries, so the padding is what has to say. kSecPaddingNone is an elliptic key
// (a curve has no padding scheme) and the four PKCS1 digest paddings are RSA keys, one each. Before this
// the shim asked for the ECDSA digest algorithm whatever the padding was, which is right for the elliptic
// key and cannot sign with an RSA one at all, so the matrix's release-RSA row could not be asked.
static SecKeyAlgorithm CharonShimAlgorithmForPadding(SecPadding padding)
{
    switch (padding) {
        case kSecPaddingPKCS1SHA1:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA1;
        case kSecPaddingPKCS1SHA224:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA224;
        case kSecPaddingPKCS1SHA256:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256;
        case kSecPaddingPKCS1SHA384:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384;
        case kSecPaddingPKCS1SHA512:
            return kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512;
        default:
            // kSecPaddingNone and everything else: the elliptic key, and the two ECDSA digest names are
            // the only other thing a curve has.
            return kSecKeyAlgorithmECDSASignatureDigestX962SHA256;
    }
}
static OSStatus CharonShimRawSign(SecKeyRef key, const uint8_t *bytes, size_t length,
                                  uint8_t *signature, size_t *signatureLength, SecPadding padding)
{
    typedef CFDataRef (*CharonShimCreateSignature)(SecKeyRef, SecKeyAlgorithm, CFDataRef, CFErrorRef *);
    static CharonShimCreateSignature host = NULL;
    if (!host) {
        host = (CharonShimCreateSignature)dlsym(RTLD_DEFAULT, "SecKeyCreateSignature");
    }
    if (!host) {
        return errSecUnimplemented;
    }
    CFErrorRef error = NULL;
    SecKeyAlgorithm algorithm = CharonShimAlgorithmForPadding(padding);
    CFDataRef digest = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
    CFDataRef made = host(key, algorithm, digest, &error);
    CFRelease(digest);
    if (error) {
        CFRelease(error);
    }
    if (!made) {
        return errSecInternalError;
    }
    size_t room = *signatureLength;
    size_t written = (size_t)CFDataGetLength(made);
    if (written > room) {
        CFRelease(made);
        return errSecParam;
    }
    memcpy(signature, CFDataGetBytePtr(made), written);
    CFRelease(made);
    *signatureLength = written;
    return errSecSuccess;
}

static OSStatus CharonShimRawVerify(SecKeyRef key, const uint8_t *bytes, size_t length,
                                    const uint8_t *signature, size_t signatureLength, SecPadding padding)
{
    typedef Boolean (*CharonShimVerifySignature)(SecKeyRef, SecKeyAlgorithm, CFDataRef, CFDataRef, CFErrorRef *);
    static CharonShimVerifySignature host = NULL;
    if (!host) {
        host = (CharonShimVerifySignature)dlsym(RTLD_DEFAULT, "SecKeyVerifySignature");
    }
    if (!host) {
        return errSecUnimplemented;
    }
    SecKeyAlgorithm algorithm = CharonShimAlgorithmForPadding(padding);
    CFDataRef digest = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
    // The release's SecKeyRawVerify takes the two halves of an elliptic signature where the host's
    // SecKeyVerifySignature takes their DER, so 64 bytes are put back into the SEQUENCE of two
    // INTEGERs here - the same shape the port's own signing reads and writes, which is what makes
    // this shim the release and not a convenience.
    uint8_t der[72];
    const uint8_t *given = signature;
    size_t givenLength = signatureLength;
    if (signatureLength == 64) {
        size_t offset = 0;
        der[offset++] = 0x30;
        der[offset++] = 0;
        size_t content = offset;
        for (int half = 0; half < 2; half++) {
            const uint8_t *value = signature + half * 32;
            int first = 0;
            while (first < 31 && value[first] == 0) {
                first++;
            }
            int size = 32 - first;
            if (value[first] & 0x80) {
                der[offset++] = 0x02;
                der[offset++] = (uint8_t)(size + 1);
                der[offset++] = 0x00;
            } else {
                der[offset++] = 0x02;
                der[offset++] = (uint8_t)size;
            }
            memcpy(der + offset, value + first, (size_t)size);
            offset += (size_t)size;
        }
        der[1] = (uint8_t)(offset - content);
        given = der;
        givenLength = offset;
    }
    CFDataRef made = CFDataCreate(kCFAllocatorDefault, given, (CFIndex)givenLength);
    CFErrorRef error = NULL;
    BOOL valid = host(key, algorithm, digest, made, &error);
    CFRelease(digest);
    CFRelease(made);
    if (error) {
        CFRelease(error);
    }
    return valid ? errSecSuccess : errSecVerifyFailed;
}

static CFDataRef CharonShimPublicBytes(SecKeyRef key)
{
    SecKeyRef publicKey = SecKeyCopyPublicKey(key);
    if (!publicKey) {
        return NULL;
    }
    CFErrorRef error = NULL;
    CFDataRef point = SecKeyCopyExternalRepresentation(publicKey, &error);
    CFRelease(publicKey);
    if (error) {
        CFRelease(error);
    }
    if (!point) {
        return NULL;
    }
    size_t length = (size_t)CFDataGetLength(point);
    if (length != 65) {
        CFRelease(point);
        return NULL;
    }
    uint8_t buffer[sizeof CharonShimSubjectPublicKeyInfo + 65];
    memcpy(buffer, CharonShimSubjectPublicKeyInfo, sizeof CharonShimSubjectPublicKeyInfo);
    memcpy(buffer + sizeof CharonShimSubjectPublicKeyInfo, CFDataGetBytePtr(point), 65);
    CFRelease(point);
    return CFDataCreate(kCFAllocatorDefault, buffer, (CFIndex)sizeof buffer);
}

static OSStatus SecKeyRawSign(SecKeyRef key, SecPadding padding, const uint8_t *bytes, size_t length,
                              uint8_t *signature, size_t *signatureLength)
{
    return CharonShimRawSign(key, bytes, length, signature, signatureLength, padding);
}

static OSStatus SecKeyRawVerify(SecKeyRef key, SecPadding padding, const uint8_t *bytes, size_t length,
                                const uint8_t *signature, size_t signatureLength)
{
    return CharonShimRawVerify(key, bytes, length, signature, signatureLength, padding);
}

static CFIndex SecKeyGetAlgorithmID(SecKeyRef key)
{
    (void)key;
    return 0;
}

static OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serialized)
{
    CFDataRef bytes = CharonShimPublicBytes(key);
    if (!bytes) {
        return errSecInternalError;
    }
    *serialized = bytes;
    return errSecSuccess;
}

static SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized)
{
    (void)algorithmID;
    (void)serialized;
    return NULL;
}


#endif
