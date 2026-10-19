// MPMediaItemArtwork's bounds-and-handler initialiser, the one member of that class the 26.2 header
// declares and this release lacks.
//
// Measured, with tools/mach32_methods.py against the 6.1.3 cache and a negative control: the release's
// MPMediaItemArtwork has 13 own instance methods - initWithImage:, imageWithSize:,
// imageWithSize:atPlaybackTime:, imageDataWithSize:atPlaybackTime:, coverFlowImageWithSize:,
// albumImageWithSize:, albumImageDataWithSize:, hasArtworkAvailable, imageCropRect, bounds,
// _internal, set_internal:, dealloc - and initWithBoundsSize:requestHandler: is not among them. So the
// initialiser is a gap, and this file carries it.
//
// What it returns is a **port subclass**, and that is the whole design. The release declares
// imageWithSize: on MPMediaItemArtwork itself, so a category implementing it would be shadowed by the
// release's own method on the release's class and never run. A subclass is not: the initialiser is a
// category method (nothing to shadow - the release has no such method) whose implementation returns an
// instance of CharonHandlerMediaItemArtwork, whose imageWithSize: and bounds consult the handler. Real
// artwork - anything the release itself makes - is an MPConcreteMediaItemArtwork and is untouched; only
// artwork a caller made through this initialiser behaves this way, which is what the header describes.
//
// The initialiser discards self and returns the subclass instance, the pattern a class cluster's init
// uses, and it is ARC-safe: the release's own artwork instance is released and the caller's is the one
// that is kept.
//
//   - (instancetype)initWithBoundsSize:(CGSize)boundsSize requestHandler:(UIImage *(^)(CGSize size))requestHandler MP_API(ios(10.0));
//
// The block type is the header's own spelling.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The host check has no iOS SDK, so UIImage is only a forward declaration there: the port uses the
// header's own spelling UIImage *(^)(CGSize) and needs nothing of the class but the name.
#import "MPMediaItemStandin.h"
#else
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface CharonHandlerMediaItemArtwork : MPMediaItemArtwork
{
    CGSize _charonBounds;
    UIImage *(^_charonHandler)(CGSize);
}
- (instancetype)initWithCharonBounds:(CGSize)bounds handler:(UIImage *(^)(CGSize))handler;
@end

@implementation CharonHandlerMediaItemArtwork

- (instancetype)initWithCharonBounds:(CGSize)bounds handler:(UIImage *(^)(CGSize))handler {
    // The header marks -init unavailable on the class (it is not the way to make one), and this subclass is
    // the way: the base's -init is the one the class inherits, looked up at run time so the header's compile-time refusal
    // does not apply (performSelector: is refused under ARC for a selector of the init family).
    IMP baseInit = [MPMediaItemArtwork instanceMethodForSelector:@selector(init)];
    self = ((id (*)(id, SEL))baseInit)(self, @selector(init));
    if (self) {
        _charonBounds = bounds;
        _charonHandler = [handler copy];
    }
    return self;
}

- (UIImage *)imageWithSize:(CGSize)size {
    // The documented behaviour: the handler is asked for the size the caller wanted and its result is
    // what comes back.
    return _charonHandler ? _charonHandler(size) : nil;
}

- (CGRect)bounds {
    return CGRectMake(0, 0, _charonBounds.width, _charonBounds.height);
}

@end

@implementation MPMediaItemArtwork (Charon100)

- (instancetype)initWithBoundsSize:(CGSize)boundsSize requestHandler:(UIImage *(^)(CGSize size))requestHandler {
    return [[CharonHandlerMediaItemArtwork alloc] initWithCharonBounds:boundsSize handler:requestHandler];
}

@end
