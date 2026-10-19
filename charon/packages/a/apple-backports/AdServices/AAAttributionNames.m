#import <Foundation/Foundation.h>
#import <AdServices/AAAttribution.h>

// The token is issued by Apple's attribution service, which reaches only the releases that carry
// AdServices. The text of the domain is that service's own, read from the arm64e shared cache of
// iOS 18.0, where AAAttribution exports the symbol (facts/AdServices/AAAttribution.md).

NSErrorDomain const AAAttributionErrorDomain = @"com.apple.ap.adservices.attributionError";
