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
const char *RevenantSecProtocolOptionsServerName(const void *options);
size_t RevenantSecProtocolOptionsApplicationProtocolCount(const void *options);
const char *RevenantSecProtocolOptionsApplicationProtocolAt(const void *options, size_t index);
const void *RevenantSecProtocolOptionsCopyLocalIdentity(const void *options);
