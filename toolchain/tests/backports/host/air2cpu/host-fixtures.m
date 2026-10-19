#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface RevenantHostRevenantMetalDevice : NSObject
+ (id)shared;
- (id<MTLDevice>)device;
@end

NSString *RevenantMetalErrorDomain = @"RevenantMetalErrorDomain";

NSError *RevenantMetalError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:RevenantMetalErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation RevenantHostRevenantMetalDevice

+ (id)shared
{
    return nil;
}

- (id<MTLDevice>)device
{
    return nil;
}

@end
