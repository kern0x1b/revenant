#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface RevenantHandlerMediaItemArtwork : MPMediaItemArtwork
{
    CGSize _revenantBounds;
    UIImage *(^_revenantHandler)(CGSize);
}
- (instancetype)initWithRevenantBounds:(CGSize)bounds handler:(UIImage *(^)(CGSize))handler;
@end

@implementation RevenantHandlerMediaItemArtwork

- (instancetype)initWithRevenantBounds:(CGSize)bounds handler:(UIImage *(^)(CGSize))handler {
    IMP baseInit = [MPMediaItemArtwork instanceMethodForSelector:@selector(init)];
    self = ((id (*)(id, SEL))baseInit)(self, @selector(init));
    if (self) {
        _revenantBounds = bounds;
        _revenantHandler = [handler copy];
    }
    return self;
}

- (UIImage *)imageWithSize:(CGSize)size {
    return _revenantHandler ? _revenantHandler(size) : nil;
}

- (CGRect)bounds {
    return CGRectMake(0, 0, _revenantBounds.width, _revenantBounds.height);
}

@end

@implementation MPMediaItemArtwork (Revenant100)

- (instancetype)initWithBoundsSize:(CGSize)boundsSize requestHandler:(UIImage *(^)(CGSize size))requestHandler {
    return [[RevenantHandlerMediaItemArtwork alloc] initWithRevenantBounds:boundsSize handler:requestHandler];
}

@end
