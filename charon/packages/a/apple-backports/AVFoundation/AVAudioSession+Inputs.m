#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char CharonPreferredInputKey;

@implementation AVAudioSession (CharonInputs)

- (NSArray<AVAudioSessionPortDescription *> *)availableInputs
{
    return self.currentRoute.inputs;
}

- (AVAudioSessionPortDescription *)preferredInput
{
    AVAudioSessionPortDescription *preferred = objc_getAssociatedObject(self, &CharonPreferredInputKey);
    for (AVAudioSessionPortDescription *input in self.currentRoute.inputs) {
        if ([input.UID isEqualToString:preferred.UID])
            return input;
    }
    return nil;
}

- (BOOL)setPreferredInput:(AVAudioSessionPortDescription *)inPort error:(NSError **)outError
{
    if (!inPort) {
        objc_setAssociatedObject(self, &CharonPreferredInputKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    }
    for (AVAudioSessionPortDescription *input in self.currentRoute.inputs) {
        if ([input.UID isEqualToString:inPort.UID]) {
            objc_setAssociatedObject(self, &CharonPreferredInputKey, input, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return YES;
        }
    }
    if (outError)
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:AVAudioSessionErrorCodeResourceNotAvailable
                                    userInfo:@{NSLocalizedDescriptionKey: @"The input is not an input of the current route, and iOS 6 has no way to switch to another"}];
    return NO;
}

@end
