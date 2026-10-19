#import "CharonVideoToolbox.h"

@implementation VTFrameProcessor

- (NSError *)charon_errorWithCode:(VTFrameProcessorError)code
                        described:(NSString *)description
{
    return [NSError errorWithDomain:VTFrameProcessorErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

- (BOOL)startSessionWithConfiguration:(id<VTFrameProcessorConfiguration>)configuration
                                 error:(NSError * _Nullable * _Nullable)error
{
    if (!configuration) {
        if (error)
            *error = [self charon_errorWithCode:VTFrameProcessorInvalidParameterError
                                     described:@"The frame processor was given no configuration."];
        return NO;
    }
    if (error)
        *error = [self charon_errorWithCode:VTFrameProcessorInitializationFailed
                                 described:@"This device has no VideoToolbox frame processor, so the "
                                          @"processing pipeline cannot be initialized."];
    return NO;
}

- (BOOL)processWithParameters:(id<VTFrameProcessorParameters>)parameters
                        error:(NSError * _Nullable * _Nullable)error
{
    if (!parameters) {
        if (error)
            *error = [self charon_errorWithCode:VTFrameProcessorInvalidParameterError
                                     described:@"The frame processor was given no parameters."];
        return NO;
    }
    if (error)
        *error = [self charon_errorWithCode:VTFrameProcessorSessionNotStarted
                                 described:@"The frame processor has no session, so it cannot process "
                                          @"frames."];
    return NO;
}

- (void)processWithParameters:(id<VTFrameProcessorParameters>)parameters
            completionHandler:(void (^)(id<VTFrameProcessorParameters>, NSError * _Nullable))completionHandler
{
    if (!completionHandler)
        return;
    NSError *failure = nil;
    [self processWithParameters:parameters error:&failure];
    completionHandler(parameters, failure);
}

- (void)processWithParameters:(id<VTFrameProcessorParameters>)parameters
           frameOutputHandler:(void (^)(id<VTFrameProcessorParameters>, CMTime, BOOL, NSError * _Nullable))frameOutputHandler
{
    if (!frameOutputHandler)
        return;
    NSError *failure = nil;
    [self processWithParameters:parameters error:&failure];
    frameOutputHandler(parameters, kCMTimeInvalid, YES, failure);
}

- (void)processWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                       parameters:(id<VTFrameProcessorParameters>)parameters
{
}

- (void)endSession
{
}

@end
