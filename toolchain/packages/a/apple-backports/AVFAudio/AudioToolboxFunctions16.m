#import <AudioToolbox/AudioComponent.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

static AudioComponentValidationResult RevenantValidateComponent(AudioComponent component)
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
    *outValidationResult = RevenantValidateComponent(inComponent);
    return noErr;
}

OSStatus AudioComponentValidateWithResults(AudioComponent inComponent, CFDictionaryRef inValidationParameters,
                                           void (^inCompletionBlock)(AudioComponentValidationResult, CFDictionaryRef _Nonnull))
{
    if (inComponent == NULL || inCompletionBlock == nil) {
        return kAudio_ParamError;
    }
    AudioComponentValidationResult result = RevenantValidateComponent(inComponent);
    NSDictionary *details = @{ @"Result": @(result), @"WasCached": @NO, @"Output": @[], @"Tests": @[] };
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        inCompletionBlock(result, (__bridge CFDictionaryRef)details);
    });
    return noErr;
}
