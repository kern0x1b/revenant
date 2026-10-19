#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface CharonHostCharonMetalDevice : NSObject
+ (id)shared;
- (id<MTLDevice>)device;
@end

NSString *CharonMetalErrorDomain = @"CharonMetalErrorDomain";

NSError *CharonMetalError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:CharonMetalErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation CharonHostCharonMetalDevice

+ (id)shared
{
    return nil;
}

- (id<MTLDevice>)device
{
    return nil;
}

@end
