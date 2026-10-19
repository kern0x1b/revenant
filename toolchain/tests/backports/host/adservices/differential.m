#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <AdServices/AdServices.h>
#import "check.h"

@interface RevenantHostAAAttribution : NSObject
+ (NSString *)attributionTokenWithError:(NSError *__autoreleasing *)error;
@end

extern NSErrorDomain const revenantHost_AAAttributionErrorDomain;

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    revenant_check([revenantHost_AAAttributionErrorDomain isEqualToString:AAAttributionErrorDomain],
                 "the error domain is the one AdServices gives it",
                 [NSString stringWithFormat:@"port %@, host %@", revenantHost_AAAttributionErrorDomain, AAAttributionErrorDomain]);

    NSError *port_error = nil;
    NSString *port_token = [RevenantHostAAAttribution attributionTokenWithError:&port_error];
    NSError *system_error = nil;
    NSString *system_token = [AAAttribution attributionTokenWithError:&system_error];

    revenant_check(port_token == nil && system_token == nil, "neither side has a token",
                 [NSString stringWithFormat:@"port %@, host %@", port_token, system_token]);
    revenant_check([port_error.domain isEqualToString:system_error.domain], "the domain is the host's",
                 [NSString stringWithFormat:@"port %@, host %@", port_error.domain, system_error.domain]);
    revenant_check(port_error.code == system_error.code, "the code is the host's",
                 [NSString stringWithFormat:@"port %ld, host %ld", (long)port_error.code, (long)system_error.code]);
    revenant_check(port_error.code == AAAttributionErrorCodePlatformNotSupported,
                 "the code is the one the framework documents for a platform the service does not support",
                 [NSString stringWithFormat:@"port %ld", (long)port_error.code]);
    revenant_check(port_error.code == 3, "that code is 3, as the header gives it",
                 [NSString stringWithFormat:@"port %ld", (long)port_error.code]);

    revenant_check(![port_error.localizedDescription isEqualToString:system_error.localizedDescription],
                 "the description is the port's own, not the host's sentence about iOS",
                 [NSString stringWithFormat:@"both say %@", port_error.localizedDescription]);
    revenant_check([port_error.localizedDescription rangeOfString:@"this version of iOS"].location != NSNotFound,
                 "the description says which device it is talking about",
                 [NSString stringWithFormat:@"port %@", port_error.localizedDescription]);
    revenant_check(port_error.userInfo[NSLocalizedDescriptionKey] != nil, "the description is in userInfo, as NSError requires",
                 [NSString stringWithFormat:@"port %@", port_error.userInfo]);

    [RevenantHostAAAttribution attributionTokenWithError:nil];
    revenant_check(YES, "a nil error out-parameter is allowed", @"raised");

    Class port_class = NSClassFromString(@"RevenantHostAAAttribution");
    Class system_class = NSClassFromString(@"AAAttribution");
    revenant_check(port_class != Nil && system_class != Nil, "both classes are there to ask",
                 [NSString stringWithFormat:@"port %@, host %@", port_class, system_class]);
    revenant_check([port_class superclass] == [system_class superclass], "the port's class stands where the host's does",
                 [NSString stringWithFormat:@"port %@, host %@", NSStringFromClass([port_class superclass]), NSStringFromClass([system_class superclass])]);

    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures == 0 ? 0 : 1;
}
