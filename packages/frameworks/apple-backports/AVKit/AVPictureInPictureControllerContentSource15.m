#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@implementation AVPictureInPictureControllerContentSource
{
    AVPlayerLayer *_revenantPlayerLayer;
}

- (instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer
{
    if ((self = [super init]))
        _revenantPlayerLayer = playerLayer;
    return self;
}

- (AVPlayerLayer *)playerLayer
{
    return _revenantPlayerLayer;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVPictureInPictureControllerContentSource layer=%@>",
            _revenantPlayerLayer ? NSStringFromClass([_revenantPlayerLayer class]) : @"nil"];
}

@end

static const void *RevenantContentSourceKey = &RevenantContentSourceKey;

@interface AVPictureInPictureController (RevenantContentSource15)
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation AVPictureInPictureController (RevenantContentSource15)

- (instancetype)initWithContentSource:(AVPictureInPictureControllerContentSource *)contentSource
{
    AVPlayerLayer *layer = contentSource.playerLayer;
    if (!layer)
        return nil;
    if ((self = [self initWithPlayerLayer:layer]))
        objc_setAssociatedObject(self, RevenantContentSourceKey, contentSource, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (AVPictureInPictureControllerContentSource *)contentSource
{
    return objc_getAssociatedObject(self, RevenantContentSourceKey);
}

- (void)setContentSource:(AVPictureInPictureControllerContentSource *)contentSource
{
    objc_setAssociatedObject(self, RevenantContentSourceKey, contentSource, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (contentSource.playerLayer)
        self.playerLayer = contentSource.playerLayer;
}

@end
