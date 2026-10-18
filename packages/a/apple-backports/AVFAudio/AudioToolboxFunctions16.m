#import <AudioToolbox/AudioComponent.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

// AudioComponentValidate and AudioComponentValidateWithResults, iOS 16: whether a component can be used. The release has no
// validation call. The port answers the question the release can answer: the component is passed when an instance of it can be
// made (and is disposed at once), and failed when it cannot. The host validates in a separate process, which this port does not
// have, so the port's answer is the in-process one. The host's answer for the generic output component is passed, result 1,
// and a results dictionary whose Result key is the result (tests/backports/host/audiotoolbox-functions); the host's answer for a NULL
// component is paramErr.
//
// The options dictionary is not used. The results dictionary carries Result, and WasCached as NO (the port keeps no cache). Its
// Output and Tests arrays are empty: the host's are the report of the auval tests the host runs, which this port does not run.

static AudioComponentValidationResult CharonValidateComponent(AudioComponent component)
{
    AudioComponentInstance instance = NULL;
    if (AudioComponentInstanceNew(component, &instance) != noErr) {
        return kAudioComponentValidationResult_Failed;
    }
    AudioComponentInstanceDispose(instance);
    return kAudioComponentValidationResult_Passed;
}

OSStatus AudioComponentValidate(AudioComponent inComponent, CFDictionaryRef inValidationParameters,
                                AudioComponentValidationResult *outValidationResult)
{
    if (inComponent == NULL || outValidationResult == NULL) {
        return kAudio_ParamError;
    }
    *outValidationResult = CharonValidateComponent(inComponent);
    return noErr;
}

// The block runs once, off the calling thread: the host's answer (measured, main thread = 0) is delivered on a background queue.
OSStatus AudioComponentValidateWithResults(AudioComponent inComponent, CFDictionaryRef inValidationParameters,
                                           void (^inCompletionBlock)(AudioComponentValidationResult, CFDictionaryRef _Nonnull))
{
    if (inComponent == NULL || inCompletionBlock == nil) {
        return kAudio_ParamError;
    }
    AudioComponentValidationResult result = CharonValidateComponent(inComponent);
    NSDictionary *details = @{ @"Result": @(result), @"WasCached": @NO, @"Output": @[], @"Tests": @[] };
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        inCompletionBlock(result, (__bridge CFDictionaryRef)details);
    });
    return noErr;
}
