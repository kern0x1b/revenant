#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

NSString * const BACKPORT_IMPL(NSURLErrorBackgroundTaskCancelledReasonKey) = @"NSURLErrorBackgroundTaskCancelledReasonKey";

@implementation NSURLSessionConfiguration (RevenantBackgroundIdentifier)

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier
{
    return [self backgroundSessionConfiguration:identifier];
}

@end
