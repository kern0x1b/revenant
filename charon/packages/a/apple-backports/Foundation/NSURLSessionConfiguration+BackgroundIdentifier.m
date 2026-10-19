#import <Foundation/Foundation.h>

NSString * const NSURLErrorBackgroundTaskCancelledReasonKey = @"NSURLErrorBackgroundTaskCancelledReasonKey";

@implementation NSURLSessionConfiguration (CharonBackgroundIdentifier)

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier
{
    return [self backgroundSessionConfiguration:identifier];
}

@end
