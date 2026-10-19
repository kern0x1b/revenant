#import <Foundation/Foundation.h>
#import <Security/Security.h>

// The eleven RFC 4754 ECDSA algorithm names of iOS 17.0 (SecKey.h, kSecKeyAlgorithm*RFC4754*), which the port
// carries for every band from iOS 6.1.3. Their values are the host's own, read by dlsym off the host's
// Security.framework (tests/backports/host/commoncrypto/differential-constants.c compares every one), and the
// same strings as upstream's SecKeyAdaptors.m (all eleven match it verbatim). They are NAMES: no operation in this
// port takes them (facts/Security/RFC4754Constants.md).

const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestRFC4754 = CFSTR("algid:sign:ECDSA:digest-RFC4754");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA1 = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA1");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA224 = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA224");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA256 = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA256");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA384 = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA384");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA512 = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA512");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA1 = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA1");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA224 = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA224");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA256 = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA256");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA384 = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA384");
const SecKeyAlgorithm kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA512 = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA512");
