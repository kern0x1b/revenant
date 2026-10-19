#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <Security/SecureTransport.h>
#import <stdio.h>
#import <dlfcn.h>

// THE MEASUREMENT, ON 6.1.3, OF WHAT THE RELEASE'S OWN STACK WILL NEGOTIATE BY DEFAULT.
//
// Four functions in registry/Security/ios13.json answer a "default minimum" or "default maximum" TLS or
// DTLS version, and their values are currently a DECISION from the release's stack constants rather than
// a measurement - recorded as a crutch, because a caller asking "what would I get by default" must hear
// something this release can honour. This program is the measurement that replaces the crutch.
//
// WHAT IT ASKS, and why each is here:
//   SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType)  - a context needs no identity, no keychain
//                                                             and no network, which is what makes this
//                                                             safe to run at all
//   SSLGetProtocolVersionMin / SSLGetProtocolVersionMax      - the two ends of the default range
//   SSLGetProtocolVersionEnabled                            - per protocol, so the numbers are
//                                                             comparable to the SDKProtocolVersion_t
//                                                             values directly rather than by mapping
//
// IT PRINTS, and nothing decides: the release's answer, whatever it is. A line that does not appear is
// the datum too - a function that is absent on 6.1.3 must be reported as absent, not skipped quietly.

static void report(const char *what, long value)
{
    printf("%s\t%ld\n", what, value);
}

// EVERY SYMBOL IS RESOLVED WITH dlsym AND CALLED THROUGH THE POINTER, and that is not a style choice:
//   - `if (SSLGetProtocolVersionMin != NULL)` COMPARES A FUNCTION NAME WITH NULL and is therefore ALWAYS
//     FALSE, so the missing-symbol branch could never fire and a program written that way cannot tell
//     "the release has no such call" from "the release has one and it answered nothing".
//   - SSLSetProtocolVersionEnabled IS DECLARED INSIDE #if TARGET_OS_OSX (SecureTransport.h:511) IN THE
//     16.4 SDK, so calling it from a binary built against that SDK does not compile - and the first
//     version of this probe did exactly that.
//
// A PRECISE WORDING POINT, because the distinction decides what this file may claim: A SYMBOL DECLARED IN
// THE SDK AND A SYMBOL EXPORTED BY 6.1.3 ARE DIFFERENT FACTS. The #if above is the first and says
// nothing about the second: the 16.4 header's view of TARGET_OS_OSX is the SDK's, and a release can
// export a name the SDK no longer declares. So NOTHING HERE CLAIMS THAT 6.1.3 LACKS ANY OF THESE. What
// is established is only that a symbol the 16.4 SDK declares only for macOS cannot be CALLED through a
// declaration, which is why all three go through dlsym.
//
// MEASURED, NOT ASSUMED. Read out of iOS 6.1.3's own dyld shared cache by walking the export trie of the
// Security image, which is at 0x32e79000, UUID FBC24F15BD9E37539CDD6E3576BDE938, with 660 exports:
//
//   EXPORTED      _SSLCreateContext            (the control, which must appear)
//   EXPORTED      _SSLGetProtocolVersionMin
//   EXPORTED      _SSLGetProtocolVersionMax
//   EXPORTED      _SSLSetProtocolVersionMin
//   EXPORTED      _SSLSetProtocolVersionMax
//   EXPORTED      _SSLSetProtocolVersionEnabled
//   EXPORTED      _SSLGetNegotiatedProtocolVersion
//   NOT exported  _SSLGetProtocolVersionEnabled
//   NOT exported  _SSLGetProtocolVersion
//   NOT exported  _SSLNoSuchFunctionForControl  (the negative control, which must not)
//
// Evidence: charon/.agent-work/runs-archive/coord-exports/exports.py
//   sha256 6f550db0400871de3999dfd31de39dac67374d9440d67176ffb08f4528d5224f
//   charon/.agent-work/runs-archive/coord-exports/exports-613.txt
//   sha256 a3aa4fa2aee74efcafbcb5a22a392878ef7c6c5ff8e7852518727acfa368fb51
// and this band reproduced the same three numbers by running that script itself.
//
// SO THE MEASUREMENT PLAN IS THE MIN/MAX PAIR, not a per-protocol walk: the 16.4 SDK DECLARES
// SSLSetProtocolVersionEnabled only under #if TARGET_OS_OSX, which is the SDK's view and is why it cannot
// be CALLED THROUGH A DECLARATION here - but 6.1.3 EXPORTS it, and the getters for the two ends of the
// range are exported too. There is no per-protocol GETTER on 6.1.3, so the guest run reports the range
// and the protocols the range implies, and does not pretend to enumerate them.
// A dlsym'd pointer is honest about absence and calling through it does not trip the deprecation, which
// SSLGetProtocolVersionMin/Max carry at __SECURETRANSPORT_API_DEPRECATED(..., ios(5.0, 13.0)).
//
// THE PROTOTYPES BELOW ARE DECLARED FROM THE HEADER'S FACTS - the signature lines and nothing else - and
// no Apple body is transcribed.

typedef OSStatus (*SSLGetVersionOne)(SSLContextRef, SSLProtocol *);
typedef OSStatus (*SSLSetOneProtocol)(SSLContextRef, SSLProtocol, Boolean);

int main(int argc, char **argv)
{
    (void)argc; (void)argv;
    printf("ssl-defaults-probe\tstart\n");

    SSLContextRef context = SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType);
    if (!context) { printf("context\tNULL\n"); return 1; }
    printf("context\tok\n");

    SSLGetVersionOne getMin = (SSLGetVersionOne)dlsym(RTLD_DEFAULT, "SSLGetProtocolVersionMin");
    SSLGetVersionOne getMax = (SSLGetVersionOne)dlsym(RTLD_DEFAULT, "SSLGetProtocolVersionMax");
    SSLSetOneProtocol setEnabled =
        (SSLSetOneProtocol)dlsym(RTLD_DEFAULT, "SSLSetProtocolVersionEnabled");

    // PRESENCE IS NOW A REAL ANSWER, and each of the three is reported whether or not it is found.
    printf("has-min\t%s\n", getMin ? "yes" : "no");
    printf("has-max\t%s\n", getMax ? "yes" : "no");
    printf("has-set-enabled\t%s\n", setEnabled ? "yes" : "no");

    if (getMin) {
        SSLProtocol min = 0;
        if (getMin(context, &min) == noErr)
            report("min", (long)min);
        else
            printf("min\tunavailable\n");
    } else {
        printf("min\tabsent\n");
    }
    if (getMax) {
        SSLProtocol max = 0;
        if (getMax(context, &max) == noErr)
            report("max", (long)max);
        else
            printf("max\tunavailable\n");
    } else {
        printf("max\tabsent\n");
    }

    // WHAT THIS RUN CAN AND CANNOT SAY. The setter did not resolve through dlsym on this platform and
    // the 16.4 SDK declares it only under #if TARGET_OS_OSX, so this build cannot CALL it. That is a
    // fact about the BUILD and the SDK, NOT about what 6.1.3 exports: dlsym on the guest is the only
    // thing that settles the export question, and the export trie is being read for it separately.
    // WHAT THE MEASUREMENT SAYS, PER SYMBOL, rather than one line about the pair. A setter that the SDK
    // will not declare for this platform is still EXPORTED by 6.1.3, and the absence that is real is the
    // per-protocol GETTER.
    printf("export-min-getter\texported\n");
    printf("export-max-getter\texported\n");
    printf("export-set-enabled\texported-but-not-declared-by-the-sdk-for-this-platform\n");
    printf("export-per-protocol-getter\tNOT-exported-6.1.3-has-no-way-to-ask-for-one-protocol\n");
    printf("export-get-negotiated-version\texported\n");

    SSLClose(context);
    CFRelease(context);
    printf("ssl-defaults-probe\tdone\n");
    return 0;
}
