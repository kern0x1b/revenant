#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>

const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureDigestRFC4754) = CFSTR("algid:sign:ECDSA:digest-RFC4754");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA1) = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA1");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA224) = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA224");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA256) = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA256");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA384) = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA384");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA512) = CFSTR("algid:sign:ECDSA:digest-RFC4754:SHA512");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA1) = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA1");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA224) = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA224");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA256) = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA256");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA384) = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA384");
const SecKeyAlgorithm BACKPORT_IMPL(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA512) = CFSTR("algid:sign:ECDSA:message-RFC4754:SHA512");
