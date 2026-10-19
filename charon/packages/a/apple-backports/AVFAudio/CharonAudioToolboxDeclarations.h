#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

// The AudioToolbox functions this port defines that the iOS 16.4 SDK, which the port compiles against, does not declare: the
// AudioConverter functions of iOS 18 and iOS 26, the packet-dependency functions of iOS 26, and the 64-bit user-data functions
// of iOS 17. Their signatures are the iOS 26.2 SDK's (spec/AudioToolbox/declarations.tsv), and a newer SDK declares the same
// names with the same types, so a build against it sees compatible declarations.
//
// The types and the enumerator come from the iOS 26 SDK. The SDK defines CA_REALTIME_API, and the 16.4 SDK does not: where that
// macro is missing, the types are declared here, and the macro is defined as nothing (the realtime attribute is a compile-time
// check the port does not need).

#ifndef CA_REALTIME_API
#define CA_REALTIME_API

// CoreAudioBaseTypes.h (iOS 26): the dependency of one packet on the packets before it.
typedef struct AudioStreamPacketDependencyDescription {
    UInt32  mIsIndependentlyDecodable;
    UInt32  mPreRollCount;
    UInt32  mFlags;
    UInt32  mReserved;
} AudioStreamPacketDependencyDescription;

// AudioConverter.h (iOS 18): the options of AudioConverterNewWithOptions.
typedef UInt32 AudioConverterOptions;
enum {
    kAudioConverterOption_Unbuffered = (1 << 16)
};

// AudioConverter.h (iOS 26): the realtime-safe input callback of AudioConverterFillComplexBufferRealtimeSafe.
typedef OSStatus
(*AudioConverterComplexInputDataProcRealtimeSafe)(
                                        AudioConverterRef               inAudioConverter,
                                        UInt32 *                        ioNumberDataPackets,
                                        AudioBufferList *               ioData,
                                        AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
                                        void * __nullable               inUserData);

// The enumerator cases of iOS 17 to 26 that the 16.4 SDK does not declare, with the iOS 26.2 SDK's values (the constants host test,
// tests/backports/host/audiotoolbox-constants, checks each against that SDK).
enum {
    kAUVoiceIOProperty_OtherAudioDuckingConfiguration = 2108,
    kAudioUnitProperty_SpatialMixerAnyInputIsUsingPersonalizedHRTF = 3116,
    kAUAudioMixParameter_RemixAmount = 1,
    kAUAudioMixParameter_Style = 0,
    kAUAudioMixProperty_EnableSpatialization = 5001,
    kAUAudioMixProperty_SpatialAudioMixMetadata = 5000,
    kAUSoundIsolationSoundType_HighQualityVoice = 0,
    kAudioUnitSubType_AUAudioMix = 0x616D6978 /* 'amix' */
};
#endif

// AudioConverter.h, iOS 18: the converter made with options, and the asynchronous preparation.
extern OSStatus
AudioConverterNewWithOptions(const AudioStreamBasicDescription * inSourceFormat,
                             const AudioStreamBasicDescription * inDestinationFormat,
                             AudioConverterOptions inOptions,
                             AudioConverterRef __nullable * __nonnull outAudioConverter);

extern void
AudioConverterPrepare(UInt32 inFlags, void * __nullable ioReserved, void (^__nullable inCompletionBlock)(OSStatus));

// AudioConverter.h, iOS 26: the realtime-safe conversion, and the conversion that also returns packet dependencies.
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

// AudioFile.h, iOS 26: writing packets with their dependencies.
extern OSStatus
AudioFileWritePacketsWithDependencies(AudioFileID inAudioFile,
                                      Boolean inUseCache,
                                      UInt32 inNumBytes,
                                      const AudioStreamPacketDescription * __nullable inPacketDescriptions,
                                      const AudioStreamPacketDependencyDescription * inPacketDependencies,
                                      SInt64 inStartingPacket,
                                      UInt32 * ioNumPackets,
                                      const void * inBuffer);

// AudioFile.h, iOS 17: the user-data size as 64 bits, and a part of a chunk from an offset.
extern OSStatus
AudioFileGetUserDataSize64(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt64 * outUserDataSize);

extern OSStatus
AudioFileGetUserDataAtOffset(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, SInt64 inOffset,
                             UInt32 * ioUserDataSize, void * outUserData);

NS_ASSUME_NONNULL_END
