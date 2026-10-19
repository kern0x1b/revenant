#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <mach/mach_time.h>

NS_ASSUME_NONNULL_BEGIN

NSUInteger CharonChannelsForLayoutTag(AudioChannelLayoutTag tag);
AudioChannelLayoutTag CharonTagForChannelCount(AVAudioChannelCount channels);
AudioChannelLayoutTag CharonTagFromName(NSString *name);

@interface AVAudioUnitComponent (CharonImpl)
- (instancetype)initWithCharonComponent:(AudioComponent)component;
@end

@interface AVAudioUnitComponentManager (CharonImpl)
- (NSArray<AVAudioUnitComponent *> *)charon_allComponents;
@end

@interface AVAudioNode (CharonAVFAudioImpl)
- (void)charon_setEngine:(nullable AVAudioEngine *)engine auNode:(AUNode)node audioUnit:(nullable AudioUnit)unit;
- (NSMutableArray *_Nonnull)charon_queue;
@end

@interface AVAudioMixingDestination (CharonInit)
- (instancetype _Nonnull)initWithCharonNode:(AVAudioNode *_Nullable)node
                                     mixer:(AVAudioNode *_Nullable)mixer
                                        bus:(AVAudioNodeBus)bus;
@end

@interface AUAudioUnit (CharonNote)
+ (void)charon_noteInert:(NSString *)member why:(NSString *)why;
@end

@interface AVAudioEnvironmentNode (CharonImpl)
- (OSStatus)charon_renderOfflineToBuffer:(AudioBufferList *)buffer frames:(AVAudioFrameCount)frames;
- (void)charon_applyEnvironmentParameters;
@end

@interface AVAudioEnvironmentDistanceAttenuationParameters (CharonImpl)
- (instancetype)initWithCharonOwner:(AVAudioEnvironmentNode *)owner;
- (float)charon_gainForDistance:(float)distance;
@end

@interface AVAudioEnvironmentReverbParameters (CharonImpl)
- (instancetype)initWithCharonOwner:(AVAudioEnvironmentNode *)owner;
@end

NS_ASSUME_NONNULL_END
