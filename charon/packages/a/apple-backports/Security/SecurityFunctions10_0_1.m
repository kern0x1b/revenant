#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

// THE FOUR PUBLIC NAMES OF THIS FILE, and what dispatches out of them.
//
// SecKeyIsAlgorithmSupported, SecKeyCreateSignature, SecKeyVerifySignature and SecKeyCopyKeyExchangeResult
// are the four Security calls of iOS 10, and they are carried here for two kinds of key at once:
//
//   * a key of the RELEASE'S OWN KEYCHAIN is signed, verified and asked about with the release's own
//     primitives - SecKeyRawSign, SecKeyRawVerify, and the class this file reads out of the keychain
//     item the key was made from. The padding is this file's own mapping (CharonSecurityPaddingFor), and
//     the release's OSStatus is the answer that is passed on, because it is the release's.
//   * a key of THIS PACKAGE'S OWN KIND - one that carries its own private scalar, and that the
//     release's keychain therefore does not hold - is signed, verified and exchanged over the curve in
//     Security/SecKeyElliptic10.m, which is charon@micro-ecc.
//
// The second half used to be four more definitions of the same four public names in that file, and two
// objects of one library defining one name is a link error, not a merge: the 6.1.3 gate answered
// "duplicate symbol '_SecKeyCreateSignature' in: Security/SecKeyElliptic10.o and
// Security/SecurityFunctions10_0_1.o" and then three more. One public symbol per function, with both
// behaviours behind it, is the shape that links - and the one the port's rule of one owner per name in
// a process wants. facts/Security/SecKey.md carries the whole of it; the matrix of what each function
// answers for each kind of key, and the mutant for each cell, are in
// tests/backports/host/seckeycurve.
extern bool CharonSecurityKeyIsPortEC(SecKeyRef key);
extern bool CharonSecKeyECCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm);
extern CFDataRef CharonSecKeyECSign(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error);
extern Boolean CharonSecKeyECVerify(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData, CFDataRef signature, CFErrorRef *error);
extern CFDataRef CharonSecKeyECExchange(SecKeyRef privateKey, SecKeyAlgorithm algorithm, SecKeyRef publicKey, CFDictionaryRef parameters, CFErrorRef *error);
// The one way this library builds a CFError, from the file that has it, so that the two files do not
// answer "which domain, which code" twice and differ.
extern void CharonSecKeyFail(CFErrorRef *error, OSStatus status, NSString *description);

// SecKeyCopyAttributes, over the facility iOS 6.1.3 has.
//
// WHERE A KEY DESCRIBES ITSELF. There are two answers available on this release and this is the one taken:
// the keychain item the ref was made from, asked for by the ref, with SecItemCopyMatching and
// kSecValueRef. The other is a side table keyed by the ref, filled by the port's own SecKeyCreateWithData
// and by a wrapper around SecKeyGeneratePair. The keychain is chosen because it is the RELEASE's own
// record and not the port's: a key the port made is described by the same item the release will find,
// and a key the release made - a keychain item added by an application, or a pair from
// SecKeyGeneratePair - is described too, with no wrapper and nothing to keep in step. A side table would
// describe the port's own keys and answer nothing about anyone else's, which is a narrower function
// wearing a general one's name.
//
// It returns a COPY, and the release copies what it returns, so the caller owns it.
// THE PURE PART, and it is split out on purpose. SecKeyCopyAttributes asks the release's keychain for
// the item a key was made from, and that half cannot be exercised on a host without touching a
// keychain - which this repository must not do. What CAN be exercised is the shaping: what the answer
// does with what SecItemCopyMatching handed back. So that is its own function, it takes the result and
// nothing else, and the differential drives it on the host with a dictionary the test builds. A caller
// passing a non-dictionary, or a dictionary without the documented keys, gets NULL - the same answer the
// whole function gives.
CFDictionaryRef CharonSecurityAttributesFromItemResult(CFTypeRef result)
{
    if (!result)
        return NULL;
    // SecItemCopyMatching hands back a dictionary for kSecReturnAttributes, and only that: a request for
    // data, a reference or a persistent ref answers something else entirely, and handing that back as
    // attributes would be a lie with a CFDictionaryRef on it.
    if (CFGetTypeID(result) != CFDictionaryGetTypeID())
        return NULL;
    return (CFDictionaryRef)result;
}

// The keychain half, which is the release's own record and the only place a key says what it is.
CFDictionaryRef SecKeyCopyAttributes(SecKeyRef key)
{
    if (!key)
        return NULL;
    // The 16.4 declaration, grepped from Security.framework/Headers/SecItem.h:1162:
    //   OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result)
    // TWO arguments, with the result through the second. There is no CFAllocatorRef and no resultType in
    // this SDK, and a call shaped the other way is a call to a function that is not here.
    const void *keys[] = {kSecValueRef, kSecReturnAttributes};
    const void *values[] = {key, kCFBooleanTrue};
    CFDictionaryRef query = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2,
                                              &kCFTypeDictionaryKeyCallBacks,
                                              &kCFTypeDictionaryValueCallBacks);
    if (!query)
        return NULL;
    CFTypeRef found = NULL;
    OSStatus status = SecItemCopyMatching(query, &found);
    CFRelease(query);
    if (status != errSecSuccess)
        return NULL;
    // The answer is the object SecItemCopyMatching made, and the caller owns it: the three callers below
    // each CFRelease what they get, which is what the real SecItemCopyMatching's ownership says. This
    // released it and returned the same pointer, so every caller of this function received a freed
    // dictionary - and nothing in this band had ever called it, because the suite drives the pure half
    // (CharonSecurityAttributesFromItemResult) and the keychain half needs a key, which a host
    // differential has none of. The first time a key went through it, the release of the next object
    // trapped in __CF_IS_OBJC. One release, to the caller.
    return CharonSecurityAttributesFromItemResult(found);
}

// SecKeyIsAlgorithmSupported, key-first, as this SDK spells it:
//
//   1550  Boolean SecKeyIsAlgorithmSupported(SecKeyRef key, SecKeyOperationType operation,
//                                             SecKeyAlgorithm algorithm)
//
// so the KEY comes first and the key's own attributes say what it is - which is why the shaping half of
// SecKeyCopyAttributes is above and why the port cannot answer this as a table over
// (class, algorithm, operation): there is no class argument to read.
//
// WHAT THE ANSWER COMES FROM, and it is the release's primitives and nothing else. On iOS 6.1.3 a
// signature is SecKeyRawSign over kSecPaddingPKCS1SHA1 (kSecKey.h:660) and the key's class says which
// padding applies; an encryption is SecKeyEncrypt over the same padding. An operation the release has no
// primitive for is NO, and NO IS THE ANSWER rather than a status - this signature returns a Boolean, so
// there is nothing to fail with, and the SDK's own contract is that NO means the algorithm is not
// supported.
// The table, defined below and declared here because the function that consults it comes first in the
// file: a delegate that is not yet declared compiles as an implicit declaration under C99 and then as a
// conflicting type, which is two errors for one missing line.
bool CharonSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec);

Boolean SecKeyIsAlgorithmSupported(SecKeyRef key, SecKeyOperationType operation, SecKeyAlgorithm algorithm)
{
    // NOT `!operation`, and this is the second thing in this file that a key with a real class found:
    // kSecKeyOperationTypeSign is 0 (SecKey.h:1594), so a guard that reads a zero operation as "no
    // operation" refuses every sign question on every platform. It was invisible while the only caller
    // was a key whose class read as neither RSA nor EC, because that returned false two lines later for
    // a reason that looked like the answer. Measured before this line, through the public symbol with a
    // real in-memory EC key and the harness's keychain answer:
    //
    //   DBG enter operation=0 alg=algid:sign:ECDSA:digest-X962:SHA256
    //   IsAlgorithmSupported(EC, sign) = 0
    //
    // An operation is an enum and 0 is one of its values, so the only question here is the key and the
    // algorithm, and the operation is compared with == where it is used.
    if (!key || !algorithm)
        return false;
    // A key of this package's own kind is asked about the curve, and the answer comes from the file
    // that has the curve: its sign and verify half is the same two ECDSA digest algorithms the table
    // below gives for a release EC key, and its exchange half is the one the release cannot do at all.
    if (CharonSecurityKeyIsPortEC(key))
        return CharonSecKeyECCarries(operation, algorithm);
    // THE TWO ARGUMENTS ARE COMPARED DIFFERENTLY AND THAT IS NOT A TYPo: SecKeyOperationType is an
    // enum and SecKeyAlgorithm is a CFStringRef, so the operation is an integer comparison and the
    // algorithm is CFEqual. Writing CFEqual on both reads correctly and does not compile - nine errors
    // from one of them.
    // the key's class, from the release's own record - the one thing the key-first signature needs
    CFDictionaryRef attributes = SecKeyCopyAttributes(key);
    if (!attributes)
        return false;
    CFTypeRef type = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    bool rsa = type && CFEqual(type, kSecAttrKeyTypeRSA);
    bool ec = type && CFEqual(type, kSecAttrKeyTypeECSECPrimeRandom);
    CFRelease(attributes);
    if (!rsa && !ec) {
        // a class the release's signing and encryption primitives do not take. kSecKey.h:198 has one
        // padding, kSecPaddingPKCS1SHA1, and it is an RSA one.
        return false;
    }
    return CharonSecurityCarries(operation, algorithm, rsa, ec);
}

// The TABLE, as a pure function of the key's class, so it can be driven on a host that has no keychain
// and no key: SecKeyIsAlgorithmSupported above is this plus the one lookup that needs a key, and a
// differential that cannot separate the two cannot check either.
bool CharonSecurityCarries(SecKeyOperationType operation, SecKeyAlgorithm algorithm, bool rsa, bool ec)
{
    if (operation == kSecKeyOperationTypeSign || operation == kSecKeyOperationTypeVerify) {
        // SecKeyRawSign and SecKeyRawVerify carry these, and no other signature primitive exists here
        if (rsa) {
            // RSA over the release's only padding: a digest, not a pre-hashed value
            return CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1)
                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256)
                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384)
                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512);
        }
        // EC signing and verifying ARE the release's own primitive, and this row said otherwise. The
        // release has an EC key type: SecItem.h:802-803 declares kSecAttrKeyTypeEC
        // API_AVAILABLE(macos(10.9), ios(4.0)), two lines above the kSecAttrKeyTypeECSECPrimeRandom of
        // 10.0 that the earlier reading of this file took for the whole of the row. An earlier version
        // of this file cited SecItem.h:804-805 against :784-785 and stepped over those two lines, and
        // the same file said the opposite of it 65 lines up.
        //
        // So a key of the release's EC type is signed and verified by the release's own SecKeyRawSign
        // and SecKeyRawVerify, and the padding is this file's own mapping, CharonSecKeyPaddingFor below:
        // kSecPaddingNone for an elliptic key, which has no padding scheme, and if the release refuses
        // that then kSecPaddingPKCS1 once, with whatever the release answers passed on. The signature
        // is then read back into the two halves or its DER, whichever it is that the release filled -
        // the same reading the RSA path does.
        //
        // NOT measured on a device: which of the two paddings the 6.1.3 release takes for an EC key is
        // what tests/backports/host/seckeycurve/emulate.sh settles, and it has not run. What IS measured
        // is that the release's own primitive signs such a key, on the host, over the shim the
        // differential carries (78 checks, and the release-key half of them is the 22 that call this
        // symbol with an unmarked EC key).
        return CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256)
            || CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);
    }
    if (operation == kSecKeyOperationTypeEncrypt || operation == kSecKeyOperationTypeDecrypt) {
        // SecKeyEncrypt and SecKeyDecrypt, and RSA is what the release's padding takes
        return rsa && (CFEqual(algorithm, kSecKeyAlgorithmRSAEncryptionPKCS1)
                        || CFEqual(algorithm, kSecKeyAlgorithmRSAEncryptionOAEPSHA1AESGCM));
    }
    if (operation == kSecKeyOperationTypeKeyExchange) {
        // iOS 6.1.3 has NO key-exchange primitive at all: SecKeyCopyKeyExchangeResult arrives at 10.0.1
        // with the peer it would have exchanged with, so there is nothing on the release to exchange.
        return false;
    }
    return false;
}

// SecKeyCreateSignature, over SecKeyRawSign.
//
//    1435  CFDataRef _Nullable SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm,
//                                                   CFDataRef dataToSign, CFErrorRef *error)
//
// So the algorithm arrives as a CFStringRef and the answer is a CFDataRef, and the port's job is to turn
// the algorithm into the PADDING the release's own call takes. Every padding the 16.4 header declares,
// and what it says about each (kSecKey.h:176-218):
//
//   176  kSecPaddingNone        = 0
//   177  kSecPaddingPKCS1       = 1
//   178  kSecPaddingOAEP        = 2        iOS 2.0
//   183  kSecPaddingSigRaw      = 0x4000
//   188  kSecPaddingPKCS1MD2    = 0x8000    deprecated
//   193  kSecPaddingPKCS1MD5    = 0x8001    deprecated
//   198  kSecPaddingPKCS1SHA1   = 0x8002
//   203  kSecPaddingPKCS1SHA224 = 0x8003    iOS 2.0
//   208  kSecPaddingPKCS1SHA256 = 0x8004    iOS 2.0
//   213  kSecPaddingPKCS1SHA384 = 0x8005    iOS 2.0
//   218  kSecPaddingPKCS1SHA512 = 0x8006    iOS 2.0
//
// So the release has every padding a digest-named algorithm needs, and the raw call's own documentation
// (kSecKey.h:660) says kSecPaddingPKCS1SHA1 is what it typically takes. kSecPaddingNone is the answer for
// an algorithm the release cannot carry, and it is distinguishable from every real padding above.
// How much room the release's own signing needs, because SecKeyRawSign takes the buffer and its length
// and answers errSecParam when the room is short - which is a refusal the caller cannot tell from the
// release's dislike of the padding.
//
//   * an elliptic key's signature is a DER SEQUENCE of two INTEGERs over a 32 byte half, so at most
//     2 + 2 * (2 + 33) = 72 bytes;
//   * an RSA key's signature is one block, and the block is the modulus, which the key's own public
//     representation measures: SecKeyCopyExternalRepresentation of the public key is the modulus with its
//     leading zero, so that length bounds the signature. The length of the DATA is not a bound at all - a
//     32 byte digest is signed with a 256 byte RSA signature - and using it as the room is what made this
//     file's first elliptic case answer NULL on a host where the key really can sign: measured, through
//     the public symbol with a real in-memory EC key, IsAlgorithmSupported(EC, sign) = 1 and
//     CreateSignature(EC key) -> NULL, because 32 bytes of room cannot hold a 71 byte DER.
static size_t CharonSecuritySignatureRoom(SecKeyRef key, bool ec, CFIndex length)
{
    if (ec) {
        return 72;
    }
    SecKeyRef publicKey = SecKeyCopyPublicKey(key);
    if (publicKey) {
        CFErrorRef error = NULL;
        CFDataRef modulus = SecKeyCopyExternalRepresentation(publicKey, &error);
        CFRelease(publicKey);
        if (error) {
            CFRelease(error);
        }
        if (modulus) {
            size_t size = (size_t)CFDataGetLength(modulus);
            CFRelease(modulus);
            if (size > 1) {
                return size;
            }
        }
    }
    return (size_t)(length > 0 ? length : 0);
}

SecPadding CharonSecurityPaddingFor(SecKeyAlgorithm algorithm)
{
    if (CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256) ||
        CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256))
        // An elliptic key has no padding scheme: kSecPaddingNone is 0 and is the one that means "the
        // bytes as they are", which is what the raw call wants for a curve. It is the answer a release
        // that takes it answers first with, and the caller asks once more with kSecPaddingPKCS1 if it
        // says no - not because that padding is right for a curve, but because some releases want the
        // RSA padding name for the same call, and that is their answer to the question rather than a
        // different key. The two paddings are told apart by the errSecParam the refusal comes with.
        return kSecPaddingNone;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1))
        return kSecPaddingPKCS1SHA1;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA224))
        return kSecPaddingPKCS1SHA224;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256))
        return kSecPaddingPKCS1SHA256;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384))
        return kSecPaddingPKCS1SHA384;
    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512))
        return kSecPaddingPKCS1SHA512;
    return kSecPaddingNone;      // an algorithm the release's signing primitive does not carry
}

CFDataRef SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign,
                                CFErrorRef *error)
{
    if (!key || !algorithm || !dataToSign)
        return NULL;
    if (error)
        *error = NULL;
    // A key of this package's own kind is signed over the curve, in the file that has it. A key of the
    // release's keychain - RSA or EC - is signed by the release's own SecKeyRawSign below, with the
    // padding CharonSecurityPaddingFor chooses for its class and the release's OSStatus passed on.
    if (CharonSecurityKeyIsPortEC(key))
        return CharonSecKeyECSign(key, algorithm, dataToSign, error);
    // the key's class, and then the table, are the same two questions SecKeyIsAlgorithmSupported asks
    CFDictionaryRef attributes = SecKeyCopyAttributes(key);
    if (!attributes)
        return NULL;
    CFTypeRef type = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    bool rsa = type && CFEqual(type, kSecAttrKeyTypeRSA);
    bool ec = type && CFEqual(type, kSecAttrKeyTypeECSECPrimeRandom);
    CFRelease(attributes);
    if (!rsa && !ec) {
        // A class the release's own signing and encryption primitives do not take. This is the same
        // guard SecKeyIsAlgorithmSupported has, and it is here as well because the elliptic row of the
        // table is reached by any key whose class is not RSA: without it a key of a class the release
        // cannot sign with would be handed to the release's raw call, and the only reason the answer
        // came out NULL was that the host's own primitive refused it - measured, with a 128 bit AES key,
        // where the refusal was the host's and not the port's.
        return NULL;
    }
    if (!CharonSecurityCarries(kSecKeyOperationTypeSign, algorithm, rsa, ec))
        // NOT SUPPORTED, and the header gives no error code to say so with: this signature takes a
        // CFErrorRef, and Security.framework's own documentation for it does not name a domain or a code
        // for an unsupported algorithm. So the port returns NULL and sets NO error rather than inventing
        // one - a caller can see the absence, and the row says absence is what there is.
        return NULL;
    // The table is the filter and the padding map is total over what the table carries, so the
    // `padding == kSecPaddingNone` guard this had is gone: kSecPaddingNone is 0 AND it is the padding an
    // elliptic key takes, so a value test refuses exactly the case the table has just admitted. That was
    // the third reading of a zero as an absence in this file, after the operation in
    // SecKeyIsAlgorithmSupported and the released attributes in SecKeyCopyAttributes, and it was measured
    // the same way - through the public symbol with a real in-memory EC key and the harness's keychain
    // answer: IsAlgorithmSupported(EC, sign) = 1 and CreateSignature(EC key) -> NULL.
    SecPadding padding = CharonSecurityPaddingFor(algorithm);
    CFIndex length = CFDataGetLength(dataToSign);
    if (length < 0)
        return NULL;
    size_t room = CharonSecuritySignatureRoom(key, ec, length);
    if (room == 0)
        return NULL;
    unsigned char *buffer = calloc(room, 1);
    if (!buffer)
        return NULL;
    size_t signatureLength = room;
    OSStatus status = SecKeyRawSign(key, padding, (const uint8_t *)CFDataGetBytePtr(dataToSign),
                                     (size_t)length, buffer, &signatureLength);
    if (status == errSecParam && ec && padding == kSecPaddingNone) {
        // A release that will not take kSecPaddingNone for an elliptic key is asked once more with the
        // RSA padding name, because some releases want that name for the same call. That is the release's
        // answer to a question and not a different key, and the two are told apart by the errSecParam the
        // refusal carries. Which of the two the 6.1.3 release takes is what
        // tests/backports/host/seckeycurve/emulate.sh settles and it has not run: the host takes
        // kSecPaddingNone, which is the branch measured here.
        signatureLength = room;
        status = SecKeyRawSign(key, kSecPaddingPKCS1, (const uint8_t *)CFDataGetBytePtr(dataToSign),
                               (size_t)length, buffer, &signatureLength);
    }
    if (status != errSecSuccess) {
        free(buffer);
        return NULL;
    }
    CFDataRef signature = CFDataCreate(kCFAllocatorDefault, buffer, (CFIndex)signatureLength);
    free(buffer);
    return signature;
}

// SecKeyVerifySignature, over SecKeyRawVerify.
//
//    1451  Boolean SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData,
//                                        CFDataRef signature, CFErrorRef *error)
//
//    692   OSStatus SecKeyRawVerify(SecKeyRef key, SecPadding padding, const uint8_t *signedData,
//                                   size_t signedDataLen, const uint8_t *sig, size_t sigLen)
//
// The release's own documentation is explicit about what the padding does here (kSecKey.h:684-690):
// kSecPaddingPKCS1 has its padding CHECKED during verification, kSecPaddingNone compares the incoming
// data directly to the signature, and a PKCS1 signature whose signedData is a digest should be verified
// with the padding that names that digest - "use kSecPaddingPKCS1SHA1". So the same pure mapping that
// chooses the padding for signing chooses it for verifying, and that is the whole of the work.
Boolean SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData,
                              CFDataRef signature, CFErrorRef *error)
{
    if (!key || !algorithm || !signedData || !signature)
        return false;
    if (error)
        *error = NULL;
    // The mirror of the signing: a key of this package's kind is verified over the curve, and every
    // other key by the release's own SecKeyRawVerify.
    if (CharonSecurityKeyIsPortEC(key))
        return CharonSecKeyECVerify(key, algorithm, signedData, signature, error);
    CFDictionaryRef attributes = SecKeyCopyAttributes(key);
    if (!attributes)
        return false;
    CFTypeRef type = CFDictionaryGetValue(attributes, kSecAttrKeyType);
    bool rsa = type && CFEqual(type, kSecAttrKeyTypeRSA);
    bool ec = type && CFEqual(type, kSecAttrKeyTypeECSECPrimeRandom);
    CFRelease(attributes);
    if (!rsa && !ec) {
        return false;   // as in the signing: a class the release takes nothing from
    }
    if (!CharonSecurityCarries(kSecKeyOperationTypeVerify, algorithm, rsa, ec))
        return false;   // not carried, and for the reason the sibling gives: no error is invented
    // As in the signing: the table is the filter, and kSecPaddingNone is a padding and not an absence.
    SecPadding padding = CharonSecurityPaddingFor(algorithm);
    CFIndex signedLength = CFDataGetLength(signedData);
    CFIndex signatureLength = CFDataGetLength(signature);
    if (signedLength < 1 || signatureLength < 1)
        return false;   // the release's raw call takes a length, and zero is not something to hand it
    OSStatus status = SecKeyRawVerify(key, padding,
                                      (const uint8_t *)CFDataGetBytePtr(signedData),
                                      (size_t)signedLength,
                                      (const uint8_t *)CFDataGetBytePtr(signature),
                                      (size_t)signatureLength);
    // errSecVerifyFailed = -67808 (SecBase.h:611) is the release's own documented code for a
    // verification that did not verify. This signature answers a Boolean, and its documentation names
    // no CFError domain or code for it, so the port answers the Boolean and sets no error rather than
    // inventing a CFError a caller would handle as though the SDK had promised one.
    (void)status;
    return status == errSecSuccess;
}

// SecKeyCopyKeyExchangeResult.
//
//    1512  CFDataRef _Nullable SecKeyCopyKeyExchangeResult(SecKeyRef privateKey, SecKeyAlgorithm algorithm,
//                                                         SecKeyRef publicKey, CFDictionaryRef parameters,
//                                                         CFErrorRef *error)
//
// THERE IS NO KEY-EXCHANGE PRIMITIVE ON 6.1.3 TO BUILD THIS ON, and that was searched for in the header
// rather than assumed. Every candidate SecKey.h declares, and what each one is:
//
//    501/530  SecKeyDeriveFromPassword - a PBKDF, and API_DEPRECATED("No longer supported", macos(10.7, 12.0)).
//             It derives a key from a PASSWORD. It is not key exchange and it is not a peer key.
//    106/146  kSecKeyDerive - an ATTRIBUTE, value nonzero iff the key may be used to derive. It is a
//             property, not an operation, and deriving from a key is not exchanging with a peer.
//
// There is no SecKeyExchange, no SecKeyRawKeyExchange, no SecKeyECDH, no SecKeyDH in the 16.4 header, so
// a function arriving at 10.0.1 with a peer key and a parameter dictionary has nothing underneath it. The
// port therefore REFUSES: the table already answers kSecKeyOperationTypeKeyExchange false, and this
// reaches the same answer without a key lookup, because the answer does not depend on the key.
CFDataRef SecKeyCopyKeyExchangeResult(SecKeyRef privateKey, SecKeyAlgorithm algorithm, SecKeyRef publicKey,
                                      CFDictionaryRef parameters, CFErrorRef *error)
{
    // A key of this package's own kind exchanges over the curve, in the file that has it. The
    // parameter dictionary is carried through and the curve reads nothing from it, because the two
    // families Security names for an agreement - "Standard", and the same with a digest - are the only
    // two there are to read, and the algorithm's name says which.
    if (privateKey && CharonSecurityKeyIsPortEC(privateKey))
        return CharonSecKeyECExchange(privateKey, algorithm, publicKey, parameters, error);

    // Every other key is refused, and now with the reason and the error the caller can tell a refusal
    // from an absence - which the first version of this function did not do, and which
    // tests/backports/host/seckeycurve has asserted since it was written. The reason is the same
    // measurement the table's key-exchange row rests on: the 6.1.3 release has no key-exchange
    // primitive of any name, its only agreement being the finite-field SecDH* family, which is not a
    // curve and not what this call takes.
    CharonSecKeyFail(error, errSecParam,
                     @"the release has no elliptic key agreement: its Security exports SecKeyRawSign and SecKeyRawVerify and only the finite-field SecDH family, so a key of its keychain cannot exchange");
    return NULL;
}
