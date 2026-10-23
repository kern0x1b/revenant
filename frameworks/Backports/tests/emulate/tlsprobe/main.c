#include <CoreFoundation/CoreFoundation.h>
#include <Security/SecureTransport.h>
#include <Security/SecTrust.h>
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

// Each entry is the name a client asks for (SNI and certificate check) and the IPv4 address the probe connects to,
// resolved on the host, because the guest's DNS does not resolve under host networking.
static const char* targets[][2] = {
    {"www.apple.com", "23.36.157.47"},
    {"www.google.com", "142.251.151.119"},
    {"www.cloudflare.com", "104.16.124.96"},
    {"tls13.cloudflare.com", "104.16.132.229"},
    {"web.telegram.org", "149.154.167.99"},
    {"api.telegram.org", "149.154.166.110"},
    {"github.com", "140.82.121.4"},
    {"letsencrypt.org", "63.176.8.218"},
    {"example.com", "172.66.147.243"},
    {"tls-v1-2.badssl.com", "104.154.89.105"},
    {NULL, NULL},
};

static const char* cipherName(uint32_t cipher)
{
    switch (cipher) {
    case 0x0004: return "RSA_WITH_RC4_128_MD5";
    case 0x0005: return "RSA_WITH_RC4_128_SHA";
    case 0x000a: return "RSA_WITH_3DES_EDE_CBC_SHA";
    case 0x002f: return "RSA_WITH_AES_128_CBC_SHA";
    case 0x0035: return "RSA_WITH_AES_256_CBC_SHA";
    case 0x003c: return "RSA_WITH_AES_128_CBC_SHA256";
    case 0x003d: return "RSA_WITH_AES_256_CBC_SHA256";
    case 0x009c: return "RSA_WITH_AES_128_GCM_SHA256";
    case 0x009d: return "RSA_WITH_AES_256_GCM_SHA384";
    case 0xc009: return "ECDHE_ECDSA_WITH_AES_128_CBC_SHA";
    case 0xc00a: return "ECDHE_ECDSA_WITH_AES_256_CBC_SHA";
    case 0xc013: return "ECDHE_RSA_WITH_AES_128_CBC_SHA";
    case 0xc014: return "ECDHE_RSA_WITH_AES_256_CBC_SHA";
    case 0xc023: return "ECDHE_ECDSA_WITH_AES_128_CBC_SHA256";
    case 0xc027: return "ECDHE_RSA_WITH_AES_128_CBC_SHA256";
    case 0xc02b: return "ECDHE_ECDSA_WITH_AES_128_GCM_SHA256";
    case 0xc02c: return "ECDHE_ECDSA_WITH_AES_256_GCM_SHA384";
    case 0xc02f: return "ECDHE_RSA_WITH_AES_128_GCM_SHA256";
    case 0xc030: return "ECDHE_RSA_WITH_AES_256_GCM_SHA384";
    default: return "other";
    }
}

static const char* versionName(SSLProtocol version)
{
    switch (version) {
    case kSSLProtocol3: return "SSL3";
    case kTLSProtocol1: return "TLS1.0";
    case kTLSProtocol11: return "TLS1.1";
    case kTLSProtocol12: return "TLS1.2";
    default: return "other";
    }
}

static OSStatus readFunction(SSLConnectionRef connection, void* data, size_t* length)
{
    ssize_t count = read((int)(intptr_t)connection, data, *length);
    if (count > 0) {
        *length = (size_t)count;
        return noErr;
    }
    *length = 0;
    return count == 0 ? errSSLClosedGraceful : errSSLClosedAbort;
}

static OSStatus writeFunction(SSLConnectionRef connection, const void* data, size_t* length)
{
    size_t done = 0;
    while (done < *length) {
        ssize_t count = write((int)(intptr_t)connection, (const char*)data + done, *length - done);
        if (count <= 0) {
            *length = done;
            return errSSLClosedAbort;
        }
        done += (size_t)count;
    }
    return noErr;
}

static void printCiphers(void)
{
    SSLContextRef context = SSLCreateContext(kCFAllocatorDefault, kSSLClientSide, kSSLStreamType);
    size_t count = 0;
    SSLGetNumberSupportedCiphers(context, &count);
    SSLCipherSuite* suites = calloc(count ? count : 1, sizeof(SSLCipherSuite));
    SSLGetSupportedCiphers(context, suites, &count);
    printf("probe: supported ciphers %lu\n", (unsigned long)count);
    for (size_t i = 0; i < count; i++) {
        printf("probe: cipher 0x%04x %s\n", (unsigned)suites[i], cipherName(suites[i]));
    }
    free(suites);
    CFRelease(context);
}

static void printVersions(void)
{
    SSLProtocol versions[] = {kSSLProtocol3, kTLSProtocol1, kTLSProtocol11, kTLSProtocol12};
    for (size_t i = 0; i < sizeof versions / sizeof versions[0]; i++) {
        SSLContextRef context = SSLCreateContext(kCFAllocatorDefault, kSSLClientSide, kSSLStreamType);
        OSStatus set = SSLSetProtocolVersionMax(context, versions[i]);
        SSLProtocol max = kSSLProtocolUnknown;
        SSLGetProtocolVersionMax(context, &max);
        printf("probe: version %s set %d max %s\n", versionName(versions[i]), (int)set, versionName(max));
        CFRelease(context);
    }
}

static int connectTo(const char* address)
{
    struct sockaddr_in peer;
    memset(&peer, 0, sizeof peer);
    peer.sin_len = sizeof peer;
    peer.sin_family = AF_INET;
    peer.sin_port = htons(443);
    if (inet_pton(AF_INET, address, &peer.sin_addr) != 1) {
        return -1;
    }
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct timeval timeout = {15, 0};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof timeout);
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof timeout);
    if (connect(fd, (struct sockaddr*)&peer, sizeof peer) != 0) {
        printf("probe: address %s connect failed errno %d\n", address, errno);
        close(fd);
        return -1;
    }
    return fd;
}

// The probe verifies the chain itself: with break-on-server-auth set, it reads the trust verdict of the firmware's
// trust store, so a trust failure is reported apart from a protocol failure.
static void handshake(const char* host, const char* address, SSLProtocol minimum, SSLProtocol maximum)
{
    int fd = connectTo(address);
    if (fd < 0) {
        return;
    }
    SSLContextRef context = SSLCreateContext(kCFAllocatorDefault, kSSLClientSide, kSSLStreamType);
    SSLSetIOFuncs(context, readFunction, writeFunction);
    SSLSetConnection(context, (SSLConnectionRef)(intptr_t)fd);
    SSLSetPeerDomainName(context, host, strlen(host));
    SSLSetProtocolVersionMin(context, minimum);
    SSLSetProtocolVersionMax(context, maximum);
    SSLSetSessionOption(context, kSSLSessionOptionBreakOnServerAuth, true);
    OSStatus status;
    char trust[64] = "not evaluated";
    int trusted = 1;
    do {
        status = SSLHandshake(context);
        if (status == errSSLServerAuthCompleted) {
            SecTrustRef peer = NULL;
            if (SSLCopyPeerTrust(context, &peer) == noErr && peer != NULL) {
                SecTrustResultType result = kSecTrustResultInvalid;
                OSStatus evaluate = SecTrustEvaluate(peer, &result);
                snprintf(trust, sizeof trust, "evaluate %d result %d", (int)evaluate, (int)result);
                // Proceed (1) and Unspecified (4) are trusted; anything else would fail a default handshake.
                trusted = evaluate == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified);
                CFRelease(peer);
            }
            if (!trusted) {
                break;
            }
        }
    } while (status == errSSLServerAuthCompleted);
    if (!trusted) {
        printf("probe: host %s trust rejected %s\n", host, trust);
        SSLClose(context);
        CFRelease(context);
        close(fd);
        return;
    }
    if (status == noErr) {
        SSLProtocol version = kSSLProtocolUnknown;
        SSLCipherSuite cipher = 0;
        SSLGetNegotiatedProtocolVersion(context, &version);
        SSLGetNegotiatedCipher(context, &cipher);
        printf("probe: host %s handshake ok version %s cipher 0x%04x %s trust %s\n", host, versionName(version),
               (unsigned)cipher, cipherName(cipher), trust);
    } else {
        printf("probe: host %s handshake failed %d trust %s\n", host, (int)status, trust);
    }
    SSLClose(context);
    CFRelease(context);
    close(fd);
}

int main(void)
{
    printCiphers();
    printVersions();
    for (int i = 0; targets[i][0] != NULL; i++) {
        handshake(targets[i][0], targets[i][1], kTLSProtocol1, kTLSProtocol12);
    }
    return 0;
}
