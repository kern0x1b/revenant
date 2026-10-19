#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, BEEligibilityContext) {
    BEEligibilityContextWebBrowser
};

@interface BEAvailability : NSObject

+ (void)isEligibleForContext:(BEEligibilityContext)context completionHandler:(void (^)(BOOL eligible, NSError *error))completionHandler;

@end

@implementation BEAvailability

+ (void)isEligibleForContext:(BEEligibilityContext)context completionHandler:(void (^)(BOOL eligible, NSError *error))completionHandler
{
    if (completionHandler) {
        completionHandler(NO, nil);
    }
}

@end
