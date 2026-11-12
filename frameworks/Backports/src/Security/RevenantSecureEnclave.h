#import <Security/Security.h>

bool RevenantSecureEnclaveKeyIs(SecKeyRef key);
bool RevenantSecureEnclaveKeyIsPrivate(SecKeyRef key);
bool RevenantSecureEnclaveKeyIsImported(SecKeyRef key);
CFDictionaryRef RevenantSecureEnclaveKeyCopyAttributes(SecKeyRef key);
SecKeyRef RevenantSecureEnclaveKeyCreateImported(const uint8_t point[65], const uint8_t *scalar);
OSStatus RevenantSecureEnclaveKeyPoint(SecKeyRef key, uint8_t point[65]);
OSStatus RevenantSecureEnclaveKeyScalar(SecKeyRef key, uint8_t scalar[32]);
SecKeyRef RevenantSecureEnclaveKeyCreateRandom(CFDictionaryRef parameters, CFErrorRef *error);
SecKeyRef RevenantSecureEnclaveKeyCopyPublic(SecKeyRef key);
OSStatus RevenantSecureEnclaveKeyLookup(CFDictionaryRef query, CFTypeRef *result);
OSStatus RevenantSecureEnclaveKeyDelete(CFDictionaryRef query);

OSStatus RevenantSecItemAuthenticate(bool allowUI, CFStringRef reason);
bool RevenantSecItemFlagsRequireUser(CFOptionFlags flags);
bool RevenantSecItemSystemEnforcesAccessControl(void);
