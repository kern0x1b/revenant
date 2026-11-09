#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantAllowsSoundsWhileRecordingKey;

@implementation AVAudioSession (RevenantRecordingSounds)

- (BOOL)allowHapticsAndSystemSoundsDuringRecording
{
    return [objc_getAssociatedObject(self, &RevenantAllowsSoundsWhileRecordingKey) boolValue];
}

- (BOOL)setAllowHapticsAndSystemSoundsDuringRecording:(BOOL)inValue error:(NSError **)outError
{
    objc_setAssociatedObject(self, &RevenantAllowsSoundsWhileRecordingKey, inValue ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

@end
