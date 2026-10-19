#import "CharonAUAudioUnit.h"

OSStatus CharonAURenderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                             UInt32 inNumberFrames, AudioBufferList *ioData)
{
    AUAudioUnit *owner = (__bridge AUAudioUnit *)inRefCon;
    return [owner charon_renderWithActionFlags:ioActionFlags
                                     timestamp:inTimeStamp
                                    frameCount:inNumberFrames
                                           bus:inBusNumber
                                           data:ioData];
}
