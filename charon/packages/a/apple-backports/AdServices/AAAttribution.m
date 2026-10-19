#import <Foundation/Foundation.h>
#import <AdServices/AAAttribution.h>

// The attribution token is minted by Apple's own service for a release that carries AdServices and
// is registered with it. iOS 6.1.3 carries neither, so the call has no token to hand over and says
// so with the error the framework itself documents for a platform the service does not support,
// which is what the host answers as well (facts/AdServices/AAAttribution.md).

@implementation AAAttribution

+ (NSString *)attributionTokenWithError:(NSError *__autoreleasing *)error
{
    if (error) {
        *error = [NSError errorWithDomain:AAAttributionErrorDomain
                                     code:AAAttributionErrorCodePlatformNotSupported
                                 userInfo:@{NSLocalizedDescriptionKey: @"Attribution is not available on this version of iOS."}];
    }
    return nil;
}

@end
