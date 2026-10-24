#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    float pan;
    float volume;
} RevenantSCNAudioMix;

RevenantSCNAudioMix RevenantSCNAudioMixFor(SCNMatrix4 listenerInverse, SCNVector3 position, float sourceVolume);

@class AVAudioPlayer;

@interface SCNNode (RevenantSCNAudioPlayers)
- (void)revenantRemoveFinishedAudioPlayer:(SCNAudioPlayer *)player;
- (void)revenantUpdateAudioWithListener:(SCNNode *)listener;
@end

@interface SCNAudioPlayer (RevenantSCNAudio)
- (nullable AVAudioPlayer *)revenantAVPlayer;
- (void)revenantStartOnNode:(nullable SCNNode *)node;
- (void)revenantStop;
- (void)revenantDidFinishPlayback;
- (BOOL)revenantIsSpatial;
- (float)revenantSourceVolume;
- (void)revenantApplyMix:(RevenantSCNAudioMix)mix;
@end

@interface SCNAudioSource (RevenantSCNAudio)
- (nullable NSURL *)revenantURL;
- (nullable NSData *)revenantData;
@end

NS_ASSUME_NONNULL_END
