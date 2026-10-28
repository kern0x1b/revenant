#import <Security/Security.h>

bool RevenantSecureEnclaveKeyIs(SecKeyRef key);
bool RevenantSecureEnclaveKeyIsPrivate(SecKeyRef key);
OSStatus RevenantSecureEnclaveKeyPoint(SecKeyRef key, uint8_t point[65]);
OSStatus RevenantSecureEnclaveKeyScalar(SecKeyRef key, uint8_t scalar[32]);
SecKeyRef RevenantSecureEnclaveKeyCreateRandom(CFDictionaryRef parameters, CFErrorRef *error);
SecKeyRef RevenantSecureEnclaveKeyCopyPublic(SecKeyRef key);
OSStatus RevenantSecureEnclaveKeyLookup(CFDictionaryRef query, CFTypeRef *result);
OSStatus RevenantSecureEnclaveKeyDelete(CFDictionaryRef query);

OSStatus RevenantSecItemAuthenticate(bool allowUI, CFStringRef reason);
bool RevenantSecItemFlagsRequireUser(CFOptionFlags flags);
bool RevenantSecItemSystemEnforcesAccessControl(void);
