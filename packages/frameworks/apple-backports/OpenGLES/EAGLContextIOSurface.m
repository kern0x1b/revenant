#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLIOSurface.h>
#import <objc/message.h>
#import <objc/runtime.h>

typedef BOOL (*RevenantTexImageIOSurface)(id, SEL, IOSurfaceRef, NSUInteger, NSUInteger, uint32_t, uint32_t,
                                        NSUInteger, NSUInteger, uint32_t, BOOL);

@implementation EAGLContext (RevenantIOSurface)

- (BOOL)texImageIOSurface:(IOSurfaceRef)ioSurface target:(NSUInteger)target internalFormat:(NSUInteger)internalFormat
                    width:(uint32_t)width height:(uint32_t)height format:(NSUInteger)format
                     type:(NSUInteger)type plane:(uint32_t)plane
{
    SEL flipping = @selector(texImageIOSurface:target:internalFormat:width:height:format:type:plane:invert:);
    if (![self respondsToSelector:flipping])
        return NO;
    RevenantTexImageIOSurface call = (RevenantTexImageIOSurface)objc_msgSend;
    return call(self, flipping, ioSurface, target, internalFormat, width, height, format, type, plane, NO);
}

@end
