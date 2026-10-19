// The one thing this module needs from C, exposed to Swift.
//
// The ES256 signature of an Apple Music developer token is P-256 with SHA-256, which is
// charon@micro-ecc's and is not written again here: this is a declaration, the shim, and the call
// into that package. iOS 6.1.3 has no Security framework key and no CommonCrypto signing, so the
// curve arithmetic has to come from somewhere, and the something the port already links for the
// CloudKit family is the one a token uses too.

#ifndef MUSICKIT_C_H
#define MUSICKIT_C_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* An ES256 signature of `message` with the P-256 key in `keyDer`, written into `raw` as the 64
   bytes JOSE names: the 32-byte r followed by the 32-byte s, sign pad off, s the low half. Answers
   64, or 0.

   `keyDer` is the DER a .p8's PEM body decodes to, not the PEM text: the module owns the base64 it
   already has a table for, and this reads the one fixed structure the DER is - PKCS#8, holding a
   SEC1 ECPrivateKey, whose own second field is the 32 byte scalar - and refuses anything else.

   The answer is the pair, not a DER SEQUENCE: micro-ecc produces the SEQUENCE that Security and
   Apple's own key read, and the shim converts it with charon@micro-ecc's own reader, because a JOSE
   verifier reads the raw pair and not the encoding. The first version of this said the DER was "what a
   JOSE verifier and Apple's own key both read" and returned it, and
   tests/backports/host/musickit/run.sh answered "signature bytes: 71 (JOSE ES256 is the raw r || s,
   64)". */
int CharonMusicKitSignES256(const unsigned char *keyDer,
                            size_t keyDerLength,
                            const unsigned char *message,
                            size_t messageLength,
                            unsigned char *raw,
                            size_t capacity);

#ifdef __cplusplus
}
#endif

#endif
