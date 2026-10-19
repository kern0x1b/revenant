#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
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
    IMP baseInit = [MPMediaItemArtwork instanceMethodForSelector:@selector(init)];
    self = ((id (*)(id, SEL))baseInit)(self, @selector(init));
    if (self) {
        _charonBounds = bounds;
        _charonHandler = [handler copy];
    }
    return self;
}

- (UIImage *)imageWithSize:(CGSize)size {
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
