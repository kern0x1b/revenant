#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@implementation AVPictureInPictureControllerContentSource
{
    AVPlayerLayer *_charonPlayerLayer;
}

- (instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer
{
    if ((self = [super init]))
        _charonPlayerLayer = playerLayer;
    return self;
}

- (AVPlayerLayer *)playerLayer
{
    return _charonPlayerLayer;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVPictureInPictureControllerContentSource layer=%@>",
            _charonPlayerLayer ? NSStringFromClass([_charonPlayerLayer class]) : @"nil"];
}

@end

static const void *CharonContentSourceKey = &CharonContentSourceKey;

@interface AVPictureInPictureController (CharonContentSource15)
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation AVPictureInPictureController (CharonContentSource15)

- (instancetype)initWithContentSource:(AVPictureInPictureControllerContentSource *)contentSource
{
    AVPlayerLayer *layer = contentSource.playerLayer;
    if (!layer)
        return nil;
    if ((self = [self initWithPlayerLayer:layer]))
        objc_setAssociatedObject(self, CharonContentSourceKey, contentSource, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (AVPictureInPictureControllerContentSource *)contentSource
{
    return objc_getAssociatedObject(self, CharonContentSourceKey);
}

- (void)setContentSource:(AVPictureInPictureControllerContentSource *)contentSource
{
    objc_setAssociatedObject(self, CharonContentSourceKey, contentSource, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (contentSource.playerLayer)
        self.playerLayer = contentSource.playerLayer;
}

@end
