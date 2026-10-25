#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCNNode (RevenantSCNAudioPlayers)
- (void)revenantRemoveFinishedAudioPlayer:(SCNAudioPlayer *)player;
- (void)revenantUpdateAudioAtTime:(CFTimeInterval)now;
@end

@interface SCNAudioPlayer (RevenantSCNAudio)
- (void)revenantStartOnNode:(nullable SCNNode *)node;
- (void)revenantStop;
- (void)revenantUpdateWithWorld:(SCNMatrix4)world time:(CFTimeInterval)now;
- (void)revenantDidFinishPlayback;
- (BOOL)revenantIsSpatial;
- (BOOL)revenantIsPlaying;
- (unsigned int)revenantSource;
@end

@interface SCNAudioSource (RevenantSCNAudio)
- (unsigned int)revenantBufferForSpatial:(BOOL)spatial;
- (double)revenantDuration;
- (nullable NSURL *)revenantURL;
- (nullable NSData *)revenantData;
@end

NS_ASSUME_NONNULL_END
