#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLIOSurface.h>
#import <objc/message.h>
#import <objc/runtime.h>

// The release's own EAGLContext takes an IOSurface through a nine-argument call that ends in the
// Y-flip argument, measured in the 6.1.3 armv7 cache's ObjC metadata by objc.binary_inventory
// (`-[EAGLContext texImageIOSurface:target:internalFormat:width:height:format:type:plane:invert:]`).
// The public API of iOS 11 is the same call without that argument, and it has no way to ask for a
// flip, so it is the same call with the flip off.

typedef BOOL (*CharonTexImageIOSurface)(id, SEL, IOSurfaceRef, NSUInteger, NSUInteger, uint32_t, uint32_t,
                                        NSUInteger, NSUInteger, uint32_t, BOOL);

@implementation EAGLContext (CharonIOSurface)

- (BOOL)texImageIOSurface:(IOSurfaceRef)ioSurface target:(NSUInteger)target internalFormat:(NSUInteger)internalFormat
                    width:(uint32_t)width height:(uint32_t)height format:(NSUInteger)format
                     type:(NSUInteger)type plane:(uint32_t)plane
{
    SEL flipping = @selector(texImageIOSurface:target:internalFormat:width:height:format:type:plane:invert:);
    if (![self respondsToSelector:flipping])
        return NO;
    CharonTexImageIOSurface call = (CharonTexImageIOSurface)objc_msgSend;
    return call(self, flipping, ioSurface, target, internalFormat, width, height, format, type, plane, NO);
}

@end
