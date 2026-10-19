#include <openssl/evp.h>
#include <openssl/ssl.h>
#include <string.h>

int main(void)
{
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int length = 0;
    if (!EVP_Digest("abc", 3, digest, &length, EVP_sha256(), NULL) || length != 32)
        return 1;
    static const unsigned char expected[4] = { 0xba, 0x78, 0x16, 0xbf };
    if (memcmp(digest, expected, sizeof(expected)))
        return 1;
    SSL_CTX *context = SSL_CTX_new(TLS_client_method());
    if (!context)
        return 1;
    SSL_CTX_free(context);
    return 0;
}
