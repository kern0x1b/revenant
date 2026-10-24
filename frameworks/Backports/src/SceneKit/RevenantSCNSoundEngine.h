#import <SceneKit/SceneKit.h>

@class AVAudioEngine;

@interface RevenantSCNSoundEngine : NSObject
+ (BOOL)isActive;
+ (AVAudioEngine *)nodeEngine;
+ (void)prepare;
+ (void)setListenerWorld:(SCNMatrix4)world atTime:(CFTimeInterval)now;
+ (unsigned int)newBuffer:(NSData *)data channels:(unsigned int)channels sampleRate:(double)sampleRate;
+ (void)deleteBuffer:(unsigned int)buffer;
+ (unsigned int)newSourceWithBuffer:(unsigned int)buffer relative:(BOOL)relative;
+ (void)deleteSource:(unsigned int)source;
+ (void)setSource:(unsigned int)source position:(SCNVector3)position velocity:(SCNVector3)velocity;
+ (BOOL)supportsReverb;
+ (BOOL)setSource:(unsigned int)source reverbSend:(float)level;
+ (BOOL)probeURL:(NSURL *)url sampleRate:(double *)sampleRate frames:(unsigned long long *)frames;
+ (nullable NSData *)decodeURL:(NSURL *)url channels:(unsigned int)channels sampleRate:(double *)sampleRate frames:(unsigned long long *)frames;
+ (nullable void *)procedureNamed:(const char *)name;
@end
