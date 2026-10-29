#include <Security/SecIdentity.h>
#include <Security/SecImportExport.h>
#include <Security/SecPolicy.h>
#include <Security/SecTrust.h>
#include <Security/SecureTransport.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <openssl/bio.h>
#include <openssl/pkcs12.h>
#include <openssl/ssl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define CONNECTIONS 3

struct server {
    SSL_CTX *context;
    int listener;
};

static void require(int ok, const char *what)
{
    if (!ok) {
        fprintf(stderr, "%s\n", what);
        exit(1);
    }
}

static void check(OSStatus status, const char *what)
{
    if (status != noErr) {
        fprintf(stderr, "%s: %d\n", what, (int)status);
        exit(1);
    }
}

static CFDataRef readFile(const char *path)
{
    FILE *file = fopen(path, "rb");
    require(file != NULL, "the identity file does not open");
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    unsigned char *bytes = malloc((size_t)size);
    require(bytes != NULL && fread(bytes, 1, (size_t)size, file) == (size_t)size, "the identity file does not read");
    fclose(file);
    CFDataRef data = CFDataCreate(NULL, bytes, size);
    free(bytes);
    return data;
}

static SSL_CTX *serverContext(const char *path)
{
    BIO *bio = BIO_new_file(path, "rb");
    require(bio != NULL, "the identity file does not open for the server");
    PKCS12 *p12 = d2i_PKCS12_bio(bio, NULL);
    BIO_free(bio);
    require(p12 != NULL, "the identity is not PKCS#12");
    EVP_PKEY *key = NULL;
    X509 *cert = NULL;
    STACK_OF(X509) *chain = NULL;
    require(PKCS12_parse(p12, "revenant", &key, &cert, &chain) == 1, "the server identity does not parse");
    PKCS12_free(p12);
    SSL_CTX *context = SSL_CTX_new(TLS_server_method());
    require(context != NULL, "the server context does not allocate");
    require(SSL_CTX_use_certificate(context, cert) == 1, "the server certificate is not used");
    require(SSL_CTX_use_PrivateKey(context, key) == 1, "the server key is not used");
    X509_free(cert);
    EVP_PKEY_free(key);
    sk_X509_pop_free(chain, X509_free);
    return context;
}

static void *serve(void *argument)
{
    struct server *state = argument;
    for (int connection = 0; connection < CONNECTIONS; connection++) {
        int descriptor = accept(state->listener, NULL, NULL);
        require(descriptor >= 0, "the server does not accept");
        SSL *ssl = SSL_new(state->context);
        SSL_set_fd(ssl, descriptor);
        if (SSL_accept(ssl) == 1) {
            char buffer[16];
            int count = SSL_read(ssl, buffer, sizeof buffer);
            if (count > 0)
                SSL_write(ssl, "pong", 4);
        }
        ERR_clear_error();
        SSL_free(ssl);
        close(descriptor);
    }
    return NULL;
}

static int connectTo(unsigned short port)
{
    int descriptor = socket(AF_INET, SOCK_STREAM, 0);
    require(descriptor >= 0, "the client socket does not open");
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address.sin_port = htons(port);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    require(connect(descriptor, (struct sockaddr *)&address, sizeof address) == 0, "the client does not connect");
    return descriptor;
}

static SSLContextRef newClient(int descriptor, Boolean breaksOnServerAuth)
{
    SSLContextRef context = SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType);
    require(context != NULL, "SSLCreateContext returned NULL");
    check(SSLSetConnection(context, (SSLConnectionRef)(intptr_t)descriptor), "SSLSetConnection");
    check(SSLSetPeerDomainName(context, "localhost", 9), "SSLSetPeerDomainName");
    if (breaksOnServerAuth)
        check(SSLSetSessionOption(context, kSSLSessionOptionBreakOnServerAuth, true), "SSLSetSessionOption");
    return context;
}

static OSStatus drive(SSLContextRef context)
{
    OSStatus status;
    do {
        status = SSLHandshake(context);
    } while (status == errSSLWouldBlock);
    return status;
}

static int evaluate(SecTrustRef trust, CFArrayRef anchors)
{
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    check(SecTrustSetPolicies(trust, policy), "SecTrustSetPolicies");
    CFRelease(policy);
    if (anchors) {
        check(SecTrustSetAnchorCertificates(trust, anchors), "SecTrustSetAnchorCertificates");
        check(SecTrustSetAnchorCertificatesOnly(trust, true), "SecTrustSetAnchorCertificatesOnly");
    }
    SecTrustResultType result = kSecTrustResultInvalid;
    check(SecTrustEvaluate(trust, &result), "SecTrustEvaluate");
    return result == kSecTrustResultProceed || result == kSecTrustResultUnspecified;
}

int main(int argc, char **argv)
{
    require(argc == 2, "usage: securetransport IDENTITY.p12");

    struct server state;
    state.context = serverContext(argv[1]);
    state.listener = socket(AF_INET, SOCK_STREAM, 0);
    require(state.listener >= 0, "the listener does not open");
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    require(bind(state.listener, (struct sockaddr *)&address, sizeof address) == 0, "the listener does not bind");
    require(listen(state.listener, CONNECTIONS) == 0, "the listener does not listen");
    socklen_t length = sizeof address;
    require(getsockname(state.listener, (struct sockaddr *)&address, &length) == 0, "the listener has no port");
    unsigned short port = ntohs(address.sin_port);
    pthread_t thread;
    require(pthread_create(&thread, NULL, serve, &state) == 0, "the server thread does not start");

    CFDataRef data = readFile(argv[1]);
    CFDictionaryRef importOptions = CFDictionaryCreate(NULL, (const void **)&kSecImportExportPassphrase, (const void **)(const CFStringRef[]){CFSTR("revenant")}, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFArrayRef items = NULL;
    check(SecPKCS12Import(data, importOptions, &items), "SecPKCS12Import");
    SecIdentityRef identity = (SecIdentityRef)CFDictionaryGetValue((CFDictionaryRef)CFArrayGetValueAtIndex(items, 0), kSecImportItemIdentity);
    SecCertificateRef leaf = NULL;
    check(SecIdentityCopyCertificate(identity, &leaf), "SecIdentityCopyCertificate");
    CFArrayRef anchors = CFArrayCreate(NULL, (const void **)&leaf, 1, &kCFTypeArrayCallBacks);

    int descriptor = connectTo(port);
    SSLContextRef strict = newClient(descriptor, false);
    printf("strict untrusted handshake status %d\n", (int)drive(strict));
    SSLClose(strict);
    SSLDisposeContext(strict);
    close(descriptor);

    descriptor = connectTo(port);
    SSLContextRef client = newClient(descriptor, true);
    OSStatus status = drive(client);
    printf("break on server auth status %d\n", (int)status);
    size_t refused = 0;
    printf("write before server auth accepted status %d\n", (int)SSLWrite(client, "ping", 4, &refused));
    SecTrustRef trust = NULL;
    check(SSLCopyPeerTrust(client, &trust), "SSLCopyPeerTrust");
    printf("anchored trust evaluation %s\n", evaluate(trust, anchors) ? "trusted" : "not trusted");
    CFRelease(trust);
    status = drive(client);
    printf("second handshake status %d\n", (int)status);
    SSLProtocol protocol = kSSLProtocolUnknown;
    check(SSLGetNegotiatedProtocolVersion(client, &protocol), "SSLGetNegotiatedProtocolVersion");
    printf("negotiated protocol %d\n", (int)protocol);
    SSLCipherSuite suite = 0;
    check(SSLGetNegotiatedCipher(client, &suite), "SSLGetNegotiatedCipher");
    printf("negotiated cipher 0x%04x\n", (unsigned)suite);
    size_t written = 0;
    check(SSLWrite(client, "ping", 4, &written), "SSLWrite");
    char buffer[16];
    size_t received = 0;
    check(SSLRead(client, buffer, sizeof buffer, &received), "SSLRead");
    printf("client received %.*s\n", (int)received, buffer);
    SSLClose(client);
    SSLDisposeContext(client);
    close(descriptor);

    descriptor = connectTo(port);
    SSLContextRef rejecting = newClient(descriptor, true);
    printf("rejecting break on server auth status %d\n", (int)drive(rejecting));
    SecTrustRef untrusted = NULL;
    check(SSLCopyPeerTrust(rejecting, &untrusted), "SSLCopyPeerTrust");
    printf("rejected untrusted evaluation %s\n", evaluate(untrusted, NULL) ? "trusted" : "not trusted");
    CFRelease(untrusted);
    SSLClose(rejecting);
    SSLDisposeContext(rejecting);
    close(descriptor);

    pthread_join(thread, NULL);
    return 0;
}
