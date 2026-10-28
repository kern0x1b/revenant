#include <Security/Security.h>
#include <stddef.h>
#include <stdint.h>

extern OSStatus SecKeyEncrypt(SecKeyRef key, SecPadding padding, const uint8_t *plain, size_t plainLength, uint8_t *cipher, size_t *cipherLength);
extern OSStatus SecKeyDecrypt(SecKeyRef key, SecPadding padding, const uint8_t *cipher, size_t cipherLength, uint8_t *plain, size_t *plainLength);
extern OSStatus SecKeyRawSign(SecKeyRef key, SecPadding padding, const uint8_t *dataToSign, size_t dataToSignLength, uint8_t *signature, size_t *signatureLength);
extern OSStatus SecKeyRawVerify(SecKeyRef key, SecPadding padding, const uint8_t *signedData, size_t signedDataLength, const uint8_t *signature, size_t signatureLength);
extern OSStatus SecKeyCopyPublicBytes(SecKeyRef key, CFDataRef *serialized);
extern SecKeyRef SecKeyCreateFromPublicData(CFAllocatorRef allocator, CFIndex algorithmID, CFDataRef serialized);
extern CFDictionaryRef SecKeyCopyAttributeDictionary(SecKeyRef key);
extern CFIndex SecKeyGetAlgorithmID(SecKeyRef key);
