#import <Foundation/Foundation.h>
#import <AdServices/AAAttribution.h>

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
