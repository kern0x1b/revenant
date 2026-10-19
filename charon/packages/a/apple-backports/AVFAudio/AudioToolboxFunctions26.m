#import <AudioToolbox/AudioConverter.h>
#import <AudioToolbox/AudioFile.h>
#import "CharonAudioToolboxDeclarations.h"

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
