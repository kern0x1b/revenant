#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <AdServices/AdServices.h>
#import "check.h"

// The port's AAAttribution against the host's own. The host is macOS, which Apple's attribution
// service does not support; iOS 6.1.3 carries no AdServices at all, so the port has to answer the
// same question the host answers: no token, and the error the framework documents for a platform the
// service does not support. The domain and the code must be the host's own; the description is the
// port's, and the test fails if it ever stops being the one that tells the truth about this device.

@interface CharonHostAAAttribution : NSObject
+ (NSString *)attributionTokenWithError:(NSError *__autoreleasing *)error;
@end

extern NSErrorDomain const charonHost_AAAttributionErrorDomain;

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    charon_check([charonHost_AAAttributionErrorDomain isEqualToString:AAAttributionErrorDomain],
                 "the error domain is the one AdServices gives it",
                 [NSString stringWithFormat:@"port %@, host %@", charonHost_AAAttributionErrorDomain, AAAttributionErrorDomain]);

    NSError *port_error = nil;
    NSString *port_token = [CharonHostAAAttribution attributionTokenWithError:&port_error];
    NSError *system_error = nil;
    NSString *system_token = [AAAttribution attributionTokenWithError:&system_error];

    charon_check(port_token == nil && system_token == nil, "neither side has a token",
                 [NSString stringWithFormat:@"port %@, host %@", port_token, system_token]);
    charon_check([port_error.domain isEqualToString:system_error.domain], "the domain is the host's",
                 [NSString stringWithFormat:@"port %@, host %@", port_error.domain, system_error.domain]);
    charon_check(port_error.code == system_error.code, "the code is the host's",
                 [NSString stringWithFormat:@"port %ld, host %ld", (long)port_error.code, (long)system_error.code]);
    charon_check(port_error.code == AAAttributionErrorCodePlatformNotSupported,
                 "the code is the one the framework documents for a platform the service does not support",
                 [NSString stringWithFormat:@"port %ld", (long)port_error.code]);
    charon_check(port_error.code == 3, "that code is 3, as the header gives it",
                 [NSString stringWithFormat:@"port %ld", (long)port_error.code]);

    // The host's text says the service is "only available on iOS and iPadOS", which is false on a
    // device that is iOS: the port says the fact in its own words, and this fails if that changes.
    charon_check(![port_error.localizedDescription isEqualToString:system_error.localizedDescription],
                 "the description is the port's own, not the host's sentence about iOS",
                 [NSString stringWithFormat:@"both say %@", port_error.localizedDescription]);
    charon_check([port_error.localizedDescription rangeOfString:@"this version of iOS"].location != NSNotFound,
                 "the description says which device it is talking about",
                 [NSString stringWithFormat:@"port %@", port_error.localizedDescription]);
    charon_check(port_error.userInfo[NSLocalizedDescriptionKey] != nil, "the description is in userInfo, as NSError requires",
                 [NSString stringWithFormat:@"port %@", port_error.userInfo]);

    [CharonHostAAAttribution attributionTokenWithError:nil];
    charon_check(YES, "a nil error out-parameter is allowed", @"raised");

    Class port_class = NSClassFromString(@"CharonHostAAAttribution");
    Class system_class = NSClassFromString(@"AAAttribution");
    charon_check(port_class != Nil && system_class != Nil, "both classes are there to ask",
                 [NSString stringWithFormat:@"port %@, host %@", port_class, system_class]);
    charon_check([port_class superclass] == [system_class superclass], "the port's class stands where the host's does",
                 [NSString stringWithFormat:@"port %@, host %@", NSStringFromClass([port_class superclass]), NSStringFromClass([system_class superclass])]);

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
