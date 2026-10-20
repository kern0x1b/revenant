#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <mach/mach_time.h>

NS_ASSUME_NONNULL_BEGIN

NSUInteger RevenantChannelsForLayoutTag(AudioChannelLayoutTag tag);
AudioChannelLayoutTag RevenantTagForChannelCount(AVAudioChannelCount channels);
AudioChannelLayoutTag RevenantTagFromName(NSString *name);

@interface AVAudioUnitComponent (RevenantImpl)
- (instancetype)initWithRevenantComponent:(AudioComponent)component;
@end

@interface AVAudioUnitComponentManager (RevenantImpl)
- (NSArray<AVAudioUnitComponent *> *)revenant_allComponents;
@end

@interface AVAudioNode (RevenantAVFAudioImpl)
- (void)revenant_setEngine:(nullable AVAudioEngine *)engine auNode:(AUNode)node audioUnit:(nullable AudioUnit)unit;
- (NSMutableArray *_Nonnull)revenant_queue;
@end

@interface AVAudioMixingDestination (RevenantInit)
- (instancetype _Nonnull)initWithRevenantNode:(AVAudioNode *_Nullable)node
                                     mixer:(AVAudioNode *_Nullable)mixer
                                        bus:(AVAudioNodeBus)bus;
@end

@interface AUAudioUnit (RevenantNote)
+ (void)revenant_noteInert:(NSString *)member why:(NSString *)why;
@end

@interface AVAudioEnvironmentNode (RevenantImpl)
- (OSStatus)revenant_renderOfflineToBuffer:(AudioBufferList *)buffer frames:(AVAudioFrameCount)frames;
- (void)revenant_applyEnvironmentParameters;
@end

@interface AVAudioEnvironmentDistanceAttenuationParameters (RevenantImpl)
- (instancetype)initWithRevenantOwner:(AVAudioEnvironmentNode *)owner;
- (float)revenant_gainForDistance:(float)distance;
@end

@interface AVAudioEnvironmentReverbParameters (RevenantImpl)
- (instancetype)initWithRevenantOwner:(AVAudioEnvironmentNode *)owner;
@end

NS_ASSUME_NONNULL_END
