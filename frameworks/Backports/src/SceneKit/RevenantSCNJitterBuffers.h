#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>

NS_ASSUME_NONNULL_BEGIN

@interface RevenantSCNJitterBuffers : NSObject
- (BOOL)isUsable;
- (void)resizeToWidth:(GLint)width height:(GLint)height;
- (void)bindSampleFramebuffer;
- (void)accumulateSampleWithWeight:(float)weight;
- (void)presentToFramebuffer:(GLuint)framebuffer;
- (void)dispose;
@end

NS_ASSUME_NONNULL_END
