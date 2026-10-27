#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/rsa.h>
#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

void *RevenantSecProtocolOptionsCreate(void);
uint16_t RevenantSecProtocolOptionsMinTLS(const void *options);
uint16_t RevenantSecProtocolOptionsMaxTLS(const void *options);
bool RevenantSecProtocolOptionsPeerAuthenticationRequired(const void *options);
bool RevenantSecProtocolOptionsOCSPEnabled(const void *options);
bool RevenantSecProtocolOptionsSCTEnabled(const void *options);
bool RevenantSecProtocolOptionsHasVerifyBlock(const void *options);
bool RevenantSecProtocolOptionsHasChallengeBlock(const void *options);
const char *RevenantSecProtocolOptionsServerName(const void *options);
size_t RevenantSecProtocolOptionsApplicationProtocolCount(const void *options);
const char *RevenantSecProtocolOptionsApplicationProtocolAt(const void *options, size_t index);
size_t RevenantSecProtocolOptionsCiphersuiteCount(const void *options);
uint32_t RevenantSecProtocolOptionsCiphersuiteAt(const void *options, size_t index);
size_t RevenantSecProtocolOptionsPreSharedKeyCount(const void *options);
size_t RevenantSecProtocolOptionsCopyData(const void *options, int kind, size_t index, void *buffer, size_t capacity);
const void *RevenantSecProtocolOptionsCopyLocalIdentity(const void *options);
const void *RevenantSecProtocolOptionsCopyChallengeIdentity(const void *options);
bool RevenantSecProtocolOptionsVerifyTrust(const void *options, const void *trust);
const char *RevenantSecProtocolOptionsUnsupportedSetting(const void *options, bool serverSide);
