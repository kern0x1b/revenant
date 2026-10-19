#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <Security/SecureTransport.h>
#import <stdio.h>
#import <dlfcn.h>

static void report(const char *what, long value)
{
    printf("%s\t%ld\n", what, value);
}

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
