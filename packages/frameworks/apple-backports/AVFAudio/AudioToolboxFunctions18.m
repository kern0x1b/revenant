#import <AudioToolbox/AudioConverter.h>
#import <dispatch/dispatch.h>
#import "RevenantAudioToolboxDeclarations.h"

OSStatus AudioConverterNewWithOptions(const AudioStreamBasicDescription *inSourceFormat,
                                      const AudioStreamBasicDescription *inDestinationFormat,
                                      AudioConverterOptions inOptions,
                                      AudioConverterRef *outAudioConverter)
{
    return AudioConverterNew(inSourceFormat, inDestinationFormat, outAudioConverter);
}

void AudioConverterPrepare(UInt32 inFlags, void *ioReserved, void (^inCompletionBlock)(OSStatus))
{
    if (inCompletionBlock == nil) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        inCompletionBlock(noErr);
    });
}
