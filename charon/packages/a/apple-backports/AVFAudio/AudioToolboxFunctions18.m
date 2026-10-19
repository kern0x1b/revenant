#import <AudioToolbox/AudioConverter.h>
#import <dispatch/dispatch.h>
#import "CharonAudioToolboxDeclarations.h"

// AudioToolbox functions of iOS 18, which the release this port runs on does not export.

// AudioConverterNewWithOptions. The release makes the converter AudioConverterNew makes, with the same answer for the same formats
// (measured on the host: with no options, and with kAudioConverterOption_Unbuffered, both give noErr for linear PCM to float).
// The one option the header defines, kAudioConverterOption_Unbuffered, asks for a converter with no buffering and restricts what it
// can be asked to do (no AudioConverterFillBuffer or AudioConverterFillComplexBuffer). The release has no such converter, so the
// option is not enforced: the converter made is buffered, and the host's refusal of FillComplexBuffer on an unbuffered converter
// (kAudioConverterErr_OperationNotSupported, 'op??', measured) is not reproduced. The conversions themselves are the same.
OSStatus AudioConverterNewWithOptions(const AudioStreamBasicDescription *inSourceFormat,
                                      const AudioStreamBasicDescription *inDestinationFormat,
                                      AudioConverterOptions inOptions,
                                      AudioConverterRef *outAudioConverter)
{
    return AudioConverterNew(inSourceFormat, inDestinationFormat, outAudioConverter);
}

// AudioConverterPrepare. The host prepares the converter machinery for later creations, so that they are quick; the release has
// nothing to prepare, so the preparation is empty and the completion is called on a background queue with noErr. The host's answer
// (measured: status 0 for flags 0 and for flags 1, off the main thread) is the same. The flags are reserved and not used.
void AudioConverterPrepare(UInt32 inFlags, void *ioReserved, void (^inCompletionBlock)(OSStatus))
{
    if (inCompletionBlock == nil) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        inCompletionBlock(noErr);
    });
}
