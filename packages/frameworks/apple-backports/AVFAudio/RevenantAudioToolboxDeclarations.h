#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef CA_REALTIME_API
#define CA_REALTIME_API

typedef struct AudioStreamPacketDependencyDescription {
    UInt32  mIsIndependentlyDecodable;
    UInt32  mPreRollCount;
    UInt32  mFlags;
    UInt32  mReserved;
} AudioStreamPacketDependencyDescription;

typedef UInt32 AudioConverterOptions;
enum {
    kAudioConverterOption_Unbuffered = (1 << 16)
};

typedef OSStatus
(*AudioConverterComplexInputDataProcRealtimeSafe)(
                                        AudioConverterRef               inAudioConverter,
                                        UInt32 *                        ioNumberDataPackets,
                                        AudioBufferList *               ioData,
                                        AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
                                        void * __nullable               inUserData);

enum {
    kAUVoiceIOProperty_OtherAudioDuckingConfiguration = 2108,
    kAudioUnitProperty_SpatialMixerAnyInputIsUsingPersonalizedHRTF = 3116,
    kAUAudioMixParameter_RemixAmount = 1,
    kAUAudioMixParameter_Style = 0,
    kAUAudioMixProperty_EnableSpatialization = 5001,
    kAUAudioMixProperty_SpatialAudioMixMetadata = 5000,
    kAUSoundIsolationSoundType_HighQualityVoice = 0,
    kAudioUnitSubType_AUAudioMix = 0x616D6978
};
#endif

extern OSStatus
AudioConverterNewWithOptions(const AudioStreamBasicDescription * inSourceFormat,
                             const AudioStreamBasicDescription * inDestinationFormat,
                             AudioConverterOptions inOptions,
                             AudioConverterRef __nullable * __nonnull outAudioConverter);

extern void
AudioConverterPrepare(UInt32 inFlags, void * __nullable ioReserved, void (^__nullable inCompletionBlock)(OSStatus));

extern OSStatus
AudioConverterFillComplexBufferRealtimeSafe(AudioConverterRef inAudioConverter,
                                            AudioConverterComplexInputDataProcRealtimeSafe inInputDataProc,
                                            void * __nullable inInputDataProcUserData,
                                            UInt32 * ioOutputDataPacketSize,
                                            AudioBufferList * outOutputData,
                                            AudioStreamPacketDescription * __nullable outPacketDescription);

extern OSStatus
AudioConverterFillComplexBufferWithPacketDependencies(AudioConverterRef inAudioConverter,
                                                      AudioConverterComplexInputDataProc inInputDataProc,
                                                      void * __nullable inInputDataProcUserData,
                                                      UInt32 * ioOutputDataPacketSize,
                                                      AudioBufferList * outOutputData,
                                                      AudioStreamPacketDescription * __nullable outPacketDescriptions,
                                                      AudioStreamPacketDependencyDescription * outPacketDependencies);

extern OSStatus
AudioFileWritePacketsWithDependencies(AudioFileID inAudioFile,
                                      Boolean inUseCache,
                                      UInt32 inNumBytes,
                                      const AudioStreamPacketDescription * __nullable inPacketDescriptions,
                                      const AudioStreamPacketDependencyDescription * inPacketDependencies,
                                      SInt64 inStartingPacket,
                                      UInt32 * ioNumPackets,
                                      const void * inBuffer);

extern OSStatus
AudioFileGetUserDataSize64(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt64 * outUserDataSize);

extern OSStatus
AudioFileGetUserDataAtOffset(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, SInt64 inOffset,
                             UInt32 * ioUserDataSize, void * outUserData);

NS_ASSUME_NONNULL_END
