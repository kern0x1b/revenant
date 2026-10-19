// host-fixtures.m — the two symbols the port's dispatch path names that a host cannot have.
//
// The pipeline builds its errors with CharonMetalError, and both the pipeline and the buffer answer
// -device with CharonMetalDevice. The device itself cannot be here: CharonMetalDevice.m makes an EAGL
// context, and a host has none - which is exactly why the port's own +[CharonMetalDevice shared]
// answers nil on a host, so this answers nil for the same reason and says so.
//
// The error constructor is not a stand-in: it builds the NSError the port builds, of the port's own
// domain and with its own code and message, because that error is what an application reads when a
// kernel the tool refused is asked for.
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
    // The port's own device makes an EAGL context and answers nil when it cannot make one, which is
    // what a host always is. The pipeline and the buffer ask the device only for -device, and nil is
    // the answer that is right here.
    return nil;
}

- (id<MTLDevice>)device
{
    return nil;
}

@end
