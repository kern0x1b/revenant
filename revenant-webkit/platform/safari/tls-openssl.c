#include <dlfcn.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <Security/SecureTransport.h>

#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/x509.h>

static bool tlsLogEnabled(void)
{
    static int enabled = -1;
    if (enabled < 0)
        enabled = access("/tmp/native-tls-log", F_OK) == 0 ? 1 : 0;
    return enabled != 0;
}

static void note(const char *format, ...)
{
    static FILE *log;
    if (!tlsLogEnabled())
        return;
    if (!log) {
        log = fopen("/tmp/native-tls.log", "a");
        if (log)
            setvbuf(log, NULL, _IOLBF, 0);
    }
    if (!log)
        return;
    va_list arguments;
    va_start(arguments, format);
    vfprintf(log, format, arguments);
    va_end(arguments);
    fputc('\n', log);
}

typedef struct Session {
    SSLContextRef context;
    SSL *ssl;
    SSL_CTX *sslContext;
    SSLReadFunc read;
    SSLWriteFunc write;
    SSLConnectionRef connection;
    char host[256];
    struct timeval startedAt;
    struct timeval wroteAt;
    struct timeval lastReadAt;
    int leftOverPending;
    size_t wroteBytes;
    size_t readBytes;
    bool awaitingFirstByte;
    bool handshakeDone;
    bool failed;
    struct Session *next;
} Session;

static Session *sessions;
static pthread_mutex_t sessionsLock = PTHREAD_MUTEX_INITIALIZER;

static Session *sessionFor(SSLContextRef context, bool create)
{
    pthread_mutex_lock(&sessionsLock);
    Session *session = sessions;
    while (session && session->context != context)
        session = session->next;
    if (!session && create) {
        session = calloc(1, sizeof(Session));
        if (session) {
            session->context = context;
            session->next = sessions;
            sessions = session;
        }
    }
    pthread_mutex_unlock(&sessionsLock);
    return session;
}

static void forgetSession(SSLContextRef context)
{
    pthread_mutex_lock(&sessionsLock);
    Session **link = &sessions;
    while (*link && (*link)->context != context)
        link = &(*link)->next;
    Session *session = *link;
    if (session) {
        *link = session->next;
        if (session->ssl)
            SSL_free(session->ssl);
        free(session);
    }
    pthread_mutex_unlock(&sessionsLock);
}

static int bioRead(BIO *bio, char *buffer, int length)
{
    Session *session = (Session *)BIO_get_data(bio);
    if (!session || !session->read || length <= 0)
        return -1;
    size_t wanted = (size_t)length;
    OSStatus status = session->read(session->connection, buffer, &wanted);
    BIO_clear_retry_flags(bio);
    if (status == errSSLWouldBlock && !wanted) {
        BIO_set_retry_read(bio);
        return -1;
    }
    if (status != noErr && status != errSSLWouldBlock && !wanted)
        return status == errSSLClosedGraceful ? 0 : -1;
    return (int)wanted;
}

static int bioWrite(BIO *bio, const char *buffer, int length)
{
    Session *session = (Session *)BIO_get_data(bio);
    if (!session || !session->write || length <= 0)
        return -1;
    size_t wanted = (size_t)length;
    OSStatus status = session->write(session->connection, buffer, &wanted);
    BIO_clear_retry_flags(bio);
    if (status == errSSLWouldBlock && !wanted) {
        BIO_set_retry_write(bio);
        return -1;
    }
    if (status != noErr && status != errSSLWouldBlock && !wanted)
        return -1;
    return (int)wanted;
}

static long bioControl(BIO *bio, int command, long argument, void *pointer)
{
    (void)bio; (void)argument; (void)pointer;
    switch (command) {
    case BIO_CTRL_FLUSH:
        return 1;
    case BIO_CTRL_PUSH:
    case BIO_CTRL_POP:
        return 0;
    default:
        return 0;
    }
}

static BIO_METHOD *transportMethod(void)
{
    static BIO_METHOD *method;
    if (!method) {
        method = BIO_meth_new(BIO_get_new_index() | BIO_TYPE_SOURCE_SINK, "CFNetwork transport");
        BIO_meth_set_read(method, bioRead);
        BIO_meth_set_write(method, bioWrite);
        BIO_meth_set_ctrl(method, bioControl);
    }
    return method;
}

#define SESSION_SLOTS 32

static struct {
    char host[256];
    SSL_SESSION *session;
} g_sessions[SESSION_SLOTS];
static pthread_mutex_t g_sessionsLock = PTHREAD_MUTEX_INITIALIZER;

static void rememberSession(const char *host, SSL *ssl)
{
    if (!host || !host[0])
        return;
    SSL_SESSION *session = SSL_get1_session(ssl);
    if (!session)
        return;
    pthread_mutex_lock(&g_sessionsLock);
    unsigned slot = 0, hash = 0;
    for (const char *c = host; *c; c++)
        hash = hash * 31u + (unsigned char)*c;
    slot = hash % SESSION_SLOTS;
    for (unsigned probe = 0; probe < 4; probe++) {
        unsigned index = (slot + probe) % SESSION_SLOTS;
        if (!g_sessions[index].host[0] || !strcmp(g_sessions[index].host, host)) {
            if (g_sessions[index].session)
                SSL_SESSION_free(g_sessions[index].session);
            strlcpy(g_sessions[index].host, host, sizeof(g_sessions[index].host));
            g_sessions[index].session = session;
            session = NULL;
            break;
        }
    }
    pthread_mutex_unlock(&g_sessionsLock);
    if (session)
        SSL_SESSION_free(session);
}

static void applyRememberedSession(const char *host, SSL *ssl)
{
    if (!host || !host[0])
        return;
    pthread_mutex_lock(&g_sessionsLock);
    unsigned hash = 0;
    for (const char *c = host; *c; c++)
        hash = hash * 31u + (unsigned char)*c;
    unsigned slot = hash % SESSION_SLOTS;
    for (unsigned probe = 0; probe < 4; probe++) {
        unsigned index = (slot + probe) % SESSION_SLOTS;
        if (g_sessions[index].session && !strcmp(g_sessions[index].host, host)) {
            SSL_set_session(ssl, g_sessions[index].session);
            break;
        }
    }
    pthread_mutex_unlock(&g_sessionsLock);
}

static bool startSession(Session *session)
{
    if (session->ssl)
        return true;

    static pthread_mutex_t contextLock = PTHREAD_MUTEX_INITIALIZER;
    static SSL_CTX *shared;
    pthread_mutex_lock(&contextLock);
    if (!shared) {
        SSL_library_init();
        SSL_load_error_strings();
        shared = SSL_CTX_new(TLS_client_method());
        if (shared) {
            SSL_CTX_set_min_proto_version(shared, TLS1_VERSION);
            SSL_CTX_set_max_proto_version(shared, TLS1_3_VERSION);
            SSL_CTX_set_session_cache_mode(shared, SSL_SESS_CACHE_CLIENT);
            SSL_CTX_sess_set_cache_size(shared, 64);
            SSL_CTX_set_mode(shared, SSL_MODE_ENABLE_PARTIAL_WRITE
                | SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER | SSL_MODE_RELEASE_BUFFERS);
            SSL_CTX_set_verify(shared, SSL_VERIFY_NONE, NULL);
        }
    }
    pthread_mutex_unlock(&contextLock);
    if (!shared)
        return false;
    session->sslContext = shared;

    session->ssl = SSL_new(session->sslContext);
    if (!session->ssl)
        return false;

    BIO *bio = BIO_new(transportMethod());
    if (!bio)
        return false;
    BIO_set_data(bio, session);
    BIO_set_init(bio, 1);
    SSL_set_bio(session->ssl, bio, bio);
    SSL_set_connect_state(session->ssl);
    applyRememberedSession(session->host, session->ssl);
    if (session->host[0]) {
        SSL_set_tlsext_host_name(session->ssl, session->host);
        X509_VERIFY_PARAM_set1_host(SSL_get0_param(session->ssl), session->host, 0);
    }
    return true;
}

OSStatus ourSSLSetIOFuncs(SSLContextRef context, SSLReadFunc readFunc, SSLWriteFunc writeFunc)
{
    Session *session = sessionFor(context, true);
    if (!session)
        return errSecAllocate;
    session->read = readFunc;
    session->write = writeFunc;
    return noErr;
}

OSStatus ourSSLSetConnection(SSLContextRef context, SSLConnectionRef connection)
{
    Session *session = sessionFor(context, true);
    if (!session)
        return errSecAllocate;
    session->connection = connection;
    return noErr;
}

OSStatus ourSSLSetPeerDomainName(SSLContextRef context, const char *name, size_t length)
{
    Session *session = sessionFor(context, true);
    if (!session)
        return errSecAllocate;
    if (length >= sizeof(session->host))
        length = sizeof(session->host) - 1;
    memcpy(session->host, name, length);
    session->host[length] = 0;
    return noErr;
}

OSStatus ourSSLGetPeerDomainNameLength(SSLContextRef context, size_t *length)
{
    Session *session = sessionFor(context, false);
    if (length)
        *length = session ? strlen(session->host) + 1 : 0;
    return noErr;
}

OSStatus ourSSLGetPeerDomainName(SSLContextRef context, char *name, size_t *length)
{
    Session *session = sessionFor(context, false);
    size_t have = session ? strlen(session->host) + 1 : 0;
    if (!length)
        return errSecParam;
    if (name && *length >= have)
        memcpy(name, session ? session->host : "", have);
    *length = have;
    return noErr;
}

OSStatus ourSSLHandshake(SSLContextRef context)
{
    Session *session = sessionFor(context, true);
    if (!session || !session->read || !session->write)
        return errSSLInternal;
    if (session->handshakeDone)
        return noErr;
    if (!session->startedAt.tv_sec)
        gettimeofday(&session->startedAt, NULL);
    if (!startSession(session)) {
        session->failed = true;
        return errSSLInternal;
    }

    int result = SSL_do_handshake(session->ssl);
    if (result == 1) {
        session->handshakeDone = true;
        struct timeval now;
        gettimeofday(&now, NULL);
        double took = (now.tv_sec - session->startedAt.tv_sec) * 1000.0
            + (now.tv_usec - session->startedAt.tv_usec) / 1000.0;
        note("handshake with %s: %s, %s, %.0f ms, resumed %d", session->host,
            SSL_get_version(session->ssl), SSL_get_cipher(session->ssl),
            took, SSL_session_reused(session->ssl));
        rememberSession(session->host, session->ssl);
        return noErr;
    }

    int error = SSL_get_error(session->ssl, result);
    if (error == SSL_ERROR_WANT_READ || error == SSL_ERROR_WANT_WRITE)
        return errSSLWouldBlock;

    note("handshake with %s failed: error %d (%s)", session->host, error,
        ERR_reason_error_string(ERR_peek_last_error()));
    session->failed = true;
    return errSSLClosedAbort;
}

OSStatus ourSSLRead(SSLContextRef context, void *data, size_t length, size_t *processed)
{
    Session *session = sessionFor(context, false);
    if (processed)
        *processed = 0;
    if (!session || !session->ssl)
        return errSSLInternal;
    if (!length)
        return noErr;

    size_t filled = 0;
    int result = 0;
    while (filled < length) {
        result = SSL_read(session->ssl, (char *)data + filled, (int)(length - filled));
        if (result <= 0)
            break;
        filled += (size_t)result;
    }
    if (filled) {
        if (session->awaitingFirstByte) {
            session->awaitingFirstByte = false;
            rememberSession(session->host, session->ssl);
        }
        if (tlsLogEnabled()) {
            struct timeval now;
            gettimeofday(&now, NULL);
            if (session->lastReadAt.tv_sec) {
                double gap = (now.tv_sec - session->lastReadAt.tv_sec) * 1000.0
                    + (now.tv_usec - session->lastReadAt.tv_usec) / 1000.0;
                if (gap > 500 && session->leftOverPending)
                    note("%s: %.0f ms between reads with %d bytes already decrypted",
                        session->host, gap, session->leftOverPending);
            }
            session->lastReadAt = now;
            session->leftOverPending = SSL_pending(session->ssl);

            double since = session->wroteAt.tv_sec
                ? (now.tv_sec - session->wroteAt.tv_sec) * 1000.0
                    + (now.tv_usec - session->wroteAt.tv_usec) / 1000.0
                : -1;
            size_t was = session->readBytes;
            session->readBytes += filled;
            if (since >= 0) {
                if (!was)
                    note("%s: first byte %.0f ms after a %zu byte request",
                        session->host, since, session->wroteBytes);
                else if (was / 32768 != session->readBytes / 32768)
                    note("%s: %zu KB in %.0f ms", session->host, session->readBytes / 1024, since);
            }
        }
        if (processed)
            *processed = filled;
        return noErr;
    }
    int error = SSL_get_error(session->ssl, result);
    if (error == SSL_ERROR_WANT_READ || error == SSL_ERROR_WANT_WRITE)
        return errSSLWouldBlock;
    if (error == SSL_ERROR_ZERO_RETURN)
        return errSSLClosedGraceful;
    return errSSLClosedAbort;
}

OSStatus ourSSLGetBufferedReadSize(SSLContextRef context, size_t *bufferSize)
{
    Session *session = sessionFor(context, false);
    if (bufferSize)
        *bufferSize = 0;
    if (!session || !session->ssl)
        return errSSLInternal;
    if (bufferSize) {
        int pending = SSL_pending(session->ssl);
        *bufferSize = pending > 0 ? (size_t)pending : 0;
    }
    return noErr;
}

OSStatus ourSSLWrite(SSLContextRef context, const void *data, size_t length, size_t *processed)
{
    Session *session = sessionFor(context, false);
    if (processed)
        *processed = 0;
    if (!session || !session->ssl)
        return errSSLInternal;
    if (!length)
        return noErr;

    int result = SSL_write(session->ssl, data, (int)length);
    if (result > 0) {
        if (!session->awaitingFirstByte) {
            gettimeofday(&session->wroteAt, NULL);
            session->awaitingFirstByte = true;
            session->wroteBytes = 0;
            session->readBytes = 0;
        }
        session->wroteBytes += (size_t)result;
        if (processed)
            *processed = (size_t)result;
        return noErr;
    }
    int error = SSL_get_error(session->ssl, result);
    if (error == SSL_ERROR_WANT_READ || error == SSL_ERROR_WANT_WRITE)
        return errSSLWouldBlock;
    return errSSLClosedAbort;
}

OSStatus ourSSLClose(SSLContextRef context)
{
    Session *session = sessionFor(context, false);
    if (session && session->ssl && session->handshakeDone)
        SSL_shutdown(session->ssl);
    forgetSession(context);
    return noErr;
}

OSStatus ourSSLCopyPeerTrust(SSLContextRef context, SecTrustRef *trust)
{
    if (trust)
        *trust = NULL;
    Session *session = sessionFor(context, false);
    if (!session || !session->ssl || !trust)
        return errSSLInternal;

    STACK_OF(X509) *chain = SSL_get_peer_cert_chain(session->ssl);
    if (!chain)
        return errSSLInternal;

    CFMutableArrayRef certificates = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    for (int i = 0; i < sk_X509_num(chain); i++) {
        X509 *certificate = sk_X509_value(chain, i);
        unsigned char *der = NULL;
        int length = i2d_X509(certificate, &der);
        if (length <= 0 || !der)
            continue;
        CFDataRef data = CFDataCreate(NULL, der, length);
        OPENSSL_free(der);
        if (!data)
            continue;
        SecCertificateRef secCertificate = SecCertificateCreateWithData(NULL, data);
        CFRelease(data);
        if (secCertificate) {
            CFArrayAppendValue(certificates, secCertificate);
            CFRelease(secCertificate);
        }
    }

    SecPolicyRef policy = NULL;
    if (session->host[0]) {
        CFStringRef host = CFStringCreateWithCString(NULL, session->host, kCFStringEncodingUTF8);
        if (host) {
            policy = SecPolicyCreateSSL(true, host);
            CFRelease(host);
        }
    }
    if (!policy)
        policy = SecPolicyCreateBasicX509();
    SecTrustRef created = NULL;
    OSStatus status = SecTrustCreateWithCertificates(certificates, policy, &created);
    if (policy)
        CFRelease(policy);
    CFRelease(certificates);
    if (status != errSecSuccess)
        return status;
    *trust = created;
    return noErr;
}

OSStatus ourSSLGetNegotiatedProtocolVersion(SSLContextRef context, SSLProtocol *protocol)
{
    Session *session = sessionFor(context, false);
    if (!protocol)
        return errSecParam;
    *protocol = kTLSProtocol12;
    if (session && session->ssl) {
        int version = SSL_version(session->ssl);
        if (version == TLS1_VERSION)
            *protocol = kTLSProtocol1;
        else if (version == TLS1_1_VERSION)
            *protocol = kTLSProtocol11;
    }
    return noErr;
}

OSStatus ourSSLGetSessionState(SSLContextRef context, SSLSessionState *state)
{
    Session *session = sessionFor(context, false);
    if (!state)
        return errSecParam;
    if (!session || !session->ssl)
        *state = kSSLIdle;
    else if (session->failed)
        *state = kSSLClosed;
    else if (session->handshakeDone)
        *state = kSSLConnected;
    else
        *state = kSSLHandshake;
    return noErr;
}

OSStatus ourSSLSetProtocolVersionMin(SSLContextRef context, SSLProtocol version) { (void)context; (void)version; return noErr; }
OSStatus ourSSLSetProtocolVersionMax(SSLContextRef context, SSLProtocol version) { (void)context; (void)version; return noErr; }
OSStatus ourSSLSetSessionOption(SSLContextRef context, SSLSessionOption option, Boolean value) { (void)context; (void)option; (void)value; return noErr; }
OSStatus ourSSLSetAllowAnonymousCiphers(SSLContextRef context, Boolean value) { (void)context; (void)value; return noErr; }
OSStatus ourSSLSetClientSideAuthenticate(SSLContextRef context, SSLAuthenticate authenticate) { (void)context; (void)authenticate; return noErr; }
OSStatus ourSSLGetClientSideAuthenticate(SSLContextRef context, SSLAuthenticate *authenticate) { (void)context; if (authenticate) *authenticate = kNeverAuthenticate; return noErr; }
OSStatus ourSSLGetClientCertificateState(SSLContextRef context, SSLClientCertificateState *state) { (void)context; if (state) *state = kSSLClientCertNone; return noErr; }
OSStatus ourSSLSetCertificate(SSLContextRef context, CFArrayRef chain) { (void)context; (void)chain; return noErr; }
OSStatus ourSSLGetCertificate(SSLContextRef context, CFArrayRef *chain) { (void)context; if (chain) *chain = NULL; return noErr; }
OSStatus ourSSLCopyDistinguishedNames(SSLContextRef context, CFArrayRef *names) { (void)context; if (names) *names = NULL; return noErr; }

OSStatus ourSSLSetPeerID(SSLContextRef context, const void *identifier, size_t length)
{
    (void)context; (void)identifier; (void)length;
    return noErr;
}

OSStatus ourSSLGetPeerID(SSLContextRef context, const void **identifier, size_t *length)
{
    (void)context;
    if (identifier)
        *identifier = NULL;
    if (length)
        *length = 0;
    return noErr;
}

extern OSStatus SSLSetAllowAnonymousCiphers(SSLContextRef, Boolean);
extern OSStatus SSLGetClientSideAuthenticate(SSLContextRef, SSLAuthenticate *);
extern OSStatus SSLGetCertificate(SSLContextRef, CFArrayRef *);

#define INTERPOSE(name) \
    __attribute__((used)) static struct { const void *replacement; const void *original; } \
    interpose_##name __attribute__((section("__DATA,__interpose"))) = \
    { (const void *)(unsigned long)&our##name, (const void *)(unsigned long)&name };

INTERPOSE(SSLSetIOFuncs)
INTERPOSE(SSLSetConnection)
INTERPOSE(SSLSetPeerDomainName)
INTERPOSE(SSLGetPeerDomainNameLength)
INTERPOSE(SSLGetPeerDomainName)
INTERPOSE(SSLHandshake)
INTERPOSE(SSLRead)
INTERPOSE(SSLGetBufferedReadSize)
INTERPOSE(SSLWrite)
INTERPOSE(SSLClose)
INTERPOSE(SSLCopyPeerTrust)
INTERPOSE(SSLGetNegotiatedProtocolVersion)
INTERPOSE(SSLGetSessionState)
INTERPOSE(SSLSetProtocolVersionMin)
INTERPOSE(SSLSetProtocolVersionMax)
INTERPOSE(SSLSetSessionOption)
INTERPOSE(SSLSetAllowAnonymousCiphers)
INTERPOSE(SSLSetClientSideAuthenticate)
INTERPOSE(SSLGetClientSideAuthenticate)
INTERPOSE(SSLGetClientCertificateState)
INTERPOSE(SSLSetCertificate)
INTERPOSE(SSLGetCertificate)
INTERPOSE(SSLCopyDistinguishedNames)
INTERPOSE(SSLSetPeerID)
INTERPOSE(SSLGetPeerID)
