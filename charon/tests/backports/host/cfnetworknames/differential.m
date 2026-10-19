#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import "check.h"

// The port's seven CFNetwork names against the host's own, which exports every one of them. The
// values were read out of the arm64e shared cache of iOS 18.0 (facts/CFNetwork/Names.md); this is the
// second, independent source: the running system has the same texts, so a value that was mistyped on
// the way out of the cache shows up here.

extern const CFStringRef charonHost_kCFHTTPVersion2_0;
extern const CFStringRef charonHost_kCFHTTPVersion3_0;
extern const CFStringRef charonHost_kCFStreamNetworkServiceTypeCallSignaling;
extern const CFStringRef charonHost_kCFStreamPropertyAllowConstrainedNetworkAccess;
extern const CFStringRef charonHost_kCFStreamPropertyAllowExpensiveNetworkAccess;
extern const CFStringRef charonHost_kCFStreamPropertyConnectionIsExpensive;
extern const CFStringRef charonHost_kCFStreamPropertySocketExtendedBackgroundIdleMode;

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
    // The host's own, looked up by the real name: the positive control is that this returns something.
    // dlsym gives the address of the variable, which holds the CFStringRef.
    CFStringRef host = NULL;
    void *found = dlsym(RTLD_DEFAULT, name);
    if (found) {
        host = *(CFStringRef *)found;
    }
    charon_check(host != NULL, "the host exports the name", [NSString stringWithFormat:@"%s is not exported here", name]);
    if (!host) {
        return;
    }
    NSString *mine = text(port);
    NSString *theirs = text(host);
    charon_check([mine isEqualToString:theirs], "the port carries the text the host has",
                 [NSString stringWithFormat:@"%s: port %@, host %@", name, mine, theirs]);
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    compare("kCFHTTPVersion2_0", charonHost_kCFHTTPVersion2_0);
    compare("kCFHTTPVersion3_0", charonHost_kCFHTTPVersion3_0);
    compare("kCFStreamNetworkServiceTypeCallSignaling", charonHost_kCFStreamNetworkServiceTypeCallSignaling);
    compare("kCFStreamPropertyAllowConstrainedNetworkAccess", charonHost_kCFStreamPropertyAllowConstrainedNetworkAccess);
    compare("kCFStreamPropertyAllowExpensiveNetworkAccess", charonHost_kCFStreamPropertyAllowExpensiveNetworkAccess);
    compare("kCFStreamPropertyConnectionIsExpensive", charonHost_kCFStreamPropertyConnectionIsExpensive);
    compare("kCFStreamPropertySocketExtendedBackgroundIdleMode", charonHost_kCFStreamPropertySocketExtendedBackgroundIdleMode);

    // The two version names are protocol lines; the five keys are the symbol's own text, which is what
    // CFNetwork does. Both are checked here so a change of either shape is caught.
    charon_check([text(charonHost_kCFHTTPVersion2_0) isEqualToString:@"HTTP/2.0"], "the HTTP/2.0 name is the protocol line",
                 text(charonHost_kCFHTTPVersion2_0));
    charon_check([text(charonHost_kCFHTTPVersion3_0) isEqualToString:@"HTTP/3.0"], "the HTTP/3.0 name is the protocol line",
                 text(charonHost_kCFHTTPVersion3_0));
    charon_check([text(charonHost_kCFStreamPropertyConnectionIsExpensive) isEqualToString:@"kCFStreamPropertyConnectionIsExpensive"],
                 "a stream property key is the symbol's own text",
                 text(charonHost_kCFStreamPropertyConnectionIsExpensive));
    charon_check(CFGetTypeID(charonHost_kCFStreamPropertyConnectionIsExpensive) == CFStringGetTypeID(),
                 "every name is a CFString, as the header declares",
                 @"not a CFString");

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
