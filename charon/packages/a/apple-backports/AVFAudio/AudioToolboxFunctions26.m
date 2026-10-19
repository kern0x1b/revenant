#import <AudioToolbox/AudioConverter.h>
#import <AudioToolbox/AudioFile.h>
#import "CharonAudioToolboxDeclarations.h"

// AudioToolbox functions of iOS 26, which the release this port runs on does not export. The release has the conversions and the
// packet writes these are built on; what the release does not have is the packet-dependency description, which these functions
// take and the release has no way to produce.

// Whether a converter's input and output formats are both linear PCM. The host's rule, as its header states it, is that only
// conversions among PCM formats are realtime safe, and a converter that needs anything else answers
// kAudioConverterErr_OperationNotSupported (measured on the host: PCM to float is noErr, PCM to ALAC is 'op??').
static BOOL CharonIsPCMConverter(AudioConverterRef converter)
{
    AudioStreamBasicDescription format = {0};
    UInt32 size = sizeof format;
    if (AudioConverterGetProperty(converter, kAudioConverterCurrentInputStreamDescription, &size, &format) != noErr
        || format.mFormatID != kAudioFormatLinearPCM) {
        return NO;
    }
    size = sizeof format;
    return AudioConverterGetProperty(converter, kAudioConverterCurrentOutputStreamDescription, &size, &format) == noErr
        && format.mFormatID == kAudioFormatLinearPCM;
}

// AudioConverterFillComplexBufferRealtimeSafe: the release's conversion for a PCM converter, with the input callback passed as the
// same function (the two callback types have the same parameters). A converter that is not PCM to PCM is refused with
// kAudioConverterErr_OperationNotSupported, as the host refuses it.
OSStatus AudioConverterFillComplexBufferRealtimeSafe(AudioConverterRef inAudioConverter,
                                                     AudioConverterComplexInputDataProcRealtimeSafe inInputDataProc,
                                                     void *inInputDataProcUserData,
                                                     UInt32 *ioOutputDataPacketSize,
                                                     AudioBufferList *outOutputData,
                                                     AudioStreamPacketDescription *outPacketDescription)
{
    if (!CharonIsPCMConverter(inAudioConverter)) {
        return kAudioConverterErr_OperationNotSupported;
    }
    return AudioConverterFillComplexBuffer(inAudioConverter, (AudioConverterComplexInputDataProc)inInputDataProc,
                                           inInputDataProcUserData, ioOutputDataPacketSize, outOutputData, outPacketDescription);
}

// AudioConverterFillComplexBufferWithPacketDependencies: the release's conversion, with the packet descriptions the host requires.
// The host answers kAudio_ParamError (-50) when the packet descriptions are NULL (measured), and when the dependencies are NULL
// (measured with the descriptions NULL too; not measured with the descriptions given). It fills the dependencies only for a format
// that employs dependent packets: the host's FormatEmploysDependentPackets is 0 for PCM and AAC (measured), and the release gives
// no dependency to fill, so the dependencies are left as they were. A format that does employ dependent packets is not measured here.
OSStatus AudioConverterFillComplexBufferWithPacketDependencies(AudioConverterRef inAudioConverter,
                                                               AudioConverterComplexInputDataProc inInputDataProc,
                                                               void *inInputDataProcUserData,
                                                               UInt32 *ioOutputDataPacketSize,
                                                               AudioBufferList *outOutputData,
                                                               AudioStreamPacketDescription *outPacketDescriptions,
                                                               AudioStreamPacketDependencyDescription *outPacketDependencies)
{
    if (outPacketDescriptions == NULL || outPacketDependencies == NULL) {
        return kAudio_ParamError;
    }
    return AudioConverterFillComplexBuffer(inAudioConverter, inInputDataProc, inInputDataProcUserData,
                                           ioOutputDataPacketSize, outOutputData, outPacketDescriptions);
}

// AudioFileWritePacketsWithDependencies: the release's packet write. The dependencies are not written anywhere (see above). The
// host accepts a NULL dependency array and returns noErr, as it does for an array (measured on a PCM WAV file).
OSStatus AudioFileWritePacketsWithDependencies(AudioFileID inAudioFile,
                                               Boolean inUseCache,
                                               UInt32 inNumBytes,
                                               const AudioStreamPacketDescription *inPacketDescriptions,
                                               const AudioStreamPacketDependencyDescription *inPacketDependencies,
                                               SInt64 inStartingPacket,
                                               UInt32 *ioNumPackets,
                                               const void *inBuffer)
{
    return AudioFileWritePackets(inAudioFile, inUseCache, inNumBytes, inPacketDescriptions, inStartingPacket, ioNumPackets, inBuffer);
}
