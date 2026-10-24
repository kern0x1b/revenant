#import <SceneKit/SceneKit.h>

@interface RevenantSCNSoundEngine : NSObject
+ (BOOL)isActive;
+ (void)prepare;
+ (void)setListenerWorld:(SCNMatrix4)world atTime:(CFTimeInterval)now;
+ (unsigned int)newBuffer:(NSData *)data channels:(unsigned int)channels sampleRate:(double)sampleRate;
+ (void)deleteBuffer:(unsigned int)buffer;
+ (unsigned int)newSourceWithBuffer:(unsigned int)buffer relative:(BOOL)relative;
+ (void)deleteSource:(unsigned int)source;
+ (void)setSource:(unsigned int)source position:(SCNVector3)position velocity:(SCNVector3)velocity;
+ (BOOL)setSource:(unsigned int)source reverbSend:(float)level;
+ (nullable NSData *)decodeURL:(NSURL *)url channels:(unsigned int)channels sampleRate:(double *)sampleRate frames:(unsigned long long *)frames;
+ (nullable void *)procedureNamed:(const char *)name;
@end
