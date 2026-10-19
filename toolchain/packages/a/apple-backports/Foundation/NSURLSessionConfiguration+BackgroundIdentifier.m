#import <Foundation/Foundation.h>

NSString * const NSURLErrorBackgroundTaskCancelledReasonKey = @"NSURLErrorBackgroundTaskCancelledReasonKey";

@implementation NSURLSessionConfiguration (RevenantBackgroundIdentifier)

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier
{
    return [self backgroundSessionConfiguration:identifier];
}

@end
