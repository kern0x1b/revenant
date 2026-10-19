#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import "check.h"

extern const CFStringRef revenantHost_kCFHTTPVersion2_0;
extern const CFStringRef revenantHost_kCFHTTPVersion3_0;
extern const CFStringRef revenantHost_kCFStreamNetworkServiceTypeCallSignaling;
extern const CFStringRef revenantHost_kCFStreamPropertyAllowConstrainedNetworkAccess;
extern const CFStringRef revenantHost_kCFStreamPropertyAllowExpensiveNetworkAccess;
extern const CFStringRef revenantHost_kCFStreamPropertyConnectionIsExpensive;
extern const CFStringRef revenantHost_kCFStreamPropertySocketExtendedBackgroundIdleMode;

static NSString *text(CFStringRef string)
{
    char buffer[256] = {0};
    if (!string || !CFStringGetCString(string, buffer, sizeof(buffer), kCFStringEncodingUTF8)) {
        return @"(not a string)";
    }
    return @(buffer);
}

static void compare(const char *name, CFStringRef port)
{
    CFStringRef host = NULL;
    void *found = dlsym(RTLD_DEFAULT, name);
    if (found) {
        host = *(CFStringRef *)found;
    }
    revenant_check(host != NULL, "the host exports the name", [NSString stringWithFormat:@"%s is not exported here", name]);
    if (!host) {
        return;
    }
    NSString *mine = text(port);
    NSString *theirs = text(host);
    revenant_check([mine isEqualToString:theirs], "the port carries the text the host has",
                 [NSString stringWithFormat:@"%s: port %@, host %@", name, mine, theirs]);
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    compare("kCFHTTPVersion2_0", revenantHost_kCFHTTPVersion2_0);
    compare("kCFHTTPVersion3_0", revenantHost_kCFHTTPVersion3_0);
    compare("kCFStreamNetworkServiceTypeCallSignaling", revenantHost_kCFStreamNetworkServiceTypeCallSignaling);
    compare("kCFStreamPropertyAllowConstrainedNetworkAccess", revenantHost_kCFStreamPropertyAllowConstrainedNetworkAccess);
    compare("kCFStreamPropertyAllowExpensiveNetworkAccess", revenantHost_kCFStreamPropertyAllowExpensiveNetworkAccess);
    compare("kCFStreamPropertyConnectionIsExpensive", revenantHost_kCFStreamPropertyConnectionIsExpensive);
    compare("kCFStreamPropertySocketExtendedBackgroundIdleMode", revenantHost_kCFStreamPropertySocketExtendedBackgroundIdleMode);

    revenant_check([text(revenantHost_kCFHTTPVersion2_0) isEqualToString:@"HTTP/2.0"], "the HTTP/2.0 name is the protocol line",
                 text(revenantHost_kCFHTTPVersion2_0));
    revenant_check([text(revenantHost_kCFHTTPVersion3_0) isEqualToString:@"HTTP/3.0"], "the HTTP/3.0 name is the protocol line",
                 text(revenantHost_kCFHTTPVersion3_0));
    revenant_check([text(revenantHost_kCFStreamPropertyConnectionIsExpensive) isEqualToString:@"kCFStreamPropertyConnectionIsExpensive"],
                 "a stream property key is the symbol's own text",
                 text(revenantHost_kCFStreamPropertyConnectionIsExpensive));
    revenant_check(CFGetTypeID(revenantHost_kCFStreamPropertyConnectionIsExpensive) == CFStringGetTypeID(),
                 "every name is a CFString, as the header declares",
                 @"not a CFString");

    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures == 0 ? 0 : 1;
}
