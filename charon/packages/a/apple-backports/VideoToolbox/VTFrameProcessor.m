#import "CharonVideoToolbox.h"

// VTFrameProcessor: the object an application starts a session on, feeds frames to, and ends.
//
// WHAT IT ANSWERS ON THIS RELEASE, and why, is the whole of this file. It is measured, not assumed:
//
//   - the release's armv7 6.1.3 cache carries no frame processor at all. `objc-inventory.lua` over
//     $HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7 and `dump-cache.lua` over the same file find no
//     VTFrameProcessor class and no VTFrameProcessor* symbol, and VideoToolbox's own header on the
//     armv7 ladder declares none of these nine methods; the seventeen configuration and parameter
//     classes arrived with iOS 26.0 and no release this package covers has one of them.
//
//   - the effects these configurations describe are motion estimation, frame interpolation, super
//     resolution and temporal noise filtering, and SDK 26.2's own header says of the super-resolution
//     scaler that it "may require ML models" and of the pipeline that it is built for hardware the
//     framework finds for itself. There is no armv7 release with a Neural Engine, and there is no
//     release with the framework that would drive one.
//
// So every member here answers exactly what SDK 26.2 documents for a device that does not have the
// hardware, which is what the port's own contract requires of it: `+isSupported` on every
// configuration class is NO, a session refuses to start with VTFrameProcessorInitializationFailed
// (the header reports that setup of the processing pipeline failed), and a frame handed to a processor with
// no session is refused with VTFrameProcessorSessionNotStarted, which the header describes as a session not yet started,
// which is the code SDK 26.2 defines for that case and not a substitute.
//
// The two things that are NOT the processor's own business are done here rather than faked:
//
//   - a nil configuration or a nil parameter is answered with VTFrameProcessorInvalidParameterError,
//     which is what SDK 26.2 reserves for an invalid argument, and it is
//     decided BEFORE the hardware question, because a caller that passes nil would get the same
//     answer on a device that has the hardware;
//   - every block-taking method RUNS its block, with the error, exactly once. An error channel that
//     leaves a caller waiting is not the documented behaviour: VTFrameProcessor.h says of
//     processWithParameters:completionHandler: where the header says the completion runs once processing of frames is done, and an authorization-
//     or download-shaped completion that never runs is
//     a hang. So the completion is called on the calling thread ahead of the method returning, which is
//     also what "asynchronously performs" means for a call that does no asynchronous work.
//
// `processWithCommandBuffer:parameters:` has no error channel AT ALL - it returns void, it takes no
// NSError, and SDK 26.2 says only "Performs effects in a Metal command buffer". That gap is Apple's,
// not the port's, and it is written up in coordination/crutches.md rather than papered over here: the
// port cannot report through a channel the header does not have, and every armv7 device a caller can
// reach this on answers +isSupported NO first.

@implementation VTFrameProcessor

// The one error this family builds, in one place, so the domain, the code and the user-info key are
// spelled once between them and cannot drift: two call sites writing `code:VTFrameProcessorSession-
// NotStarted` and one of them writing 19732 by hand would be the defect this method exists to stop.
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
    // nil first, and reported as the invalid parameter it is: this answer does not depend on the
    // hardware, so it is the answer a device WITH the hardware gives too.
    if (!configuration) {
        if (error)
            *error = [self charon_errorWithCode:VTFrameProcessorInvalidParameterError
                                     described:@"The frame processor was given no configuration."];
        return NO;
    }
    // Nothing on this release can build the pipeline, so the initialization is what fails - and that is
    // the code SDK 26.2 gives it, rather than a generic "unsupported" that is not in the enumeration.
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
    // A session never starts on this release, so no session is ever started: the error the header
    // defines for exactly this - a processor used to process frames without being started.
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
    // SDK 26.2: the handler runs one time per destination frame in the parameters given, unless an error is met;
    // the NSError parameter is where an error arrives. There are no
    // destination frames to hand over, so the call the handler sees is the one that reports the error:
    // once, with the timestamp the SDK uses for no timestamp, and marked as the final output of this
    // request, which is what that BOOL says it is.
    frameOutputHandler(parameters, kCMTimeInvalid, YES, failure);
}

- (void)processWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                       parameters:(id<VTFrameProcessorParameters>)parameters
{
    // No error channel exists here and none is invented: see the comment at the head of this file and
    // coordination/crutches.md. The parameter is not read, so nothing of it can be kept.
}

- (void)endSession
{
    // No session was ever started, so there is nothing to flush, invalidate or release. This is a
    // no-op by construction and not by omission: -startSessionWithConfiguration:error: above returns
    // NO on every call, so the state -endSession would tear down is never reached.
}

@end