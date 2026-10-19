// AVPictureInPictureControllerContentSource15.m - the 15.0 content source: the class itself, and the
// two members of AVPictureInPictureController that carry it. One object, one release; every name
// below is ios(15.0) in the SDK 26.2 header.
//
// Why the player-layer half is real and the sample-buffer half is not. A content source is a box for
// one of two things (AVPictureInPictureController_AVSampleBufferDisplayLayerSupport.h:109-131):
// either a player layer, or a sample-buffer display layer with a playback delegate. The first box is
// this port's own picture-in-picture: AVPictureInPictureController.m already reparents a real
// AVPlayerLayer into its floating window, and AVPlayerLayer is measured present and exported on this
// release, so the box holds the very layer that window uses and -initWithContentSource: hands that
// same window its source. The second box is not carried, and the reason is measured rather than
// assumed: AVSampleBufferDisplayLayer is in the armv7 shared cache of 6.1.3 (first rung 6.0, class
// and metaclass symbols both there), but this release has no picture-in-picture at all, so nothing
// ever asks a sample-buffer display layer to play, and the six-method protocol that would drive it
// (AVPictureInPictureSampleBufferPlaybackDelegate) is 15.0 API that no release before 15.0 carries.
// The port therefore registers that protocol absent, and says there that the missing half is the
// sample-buffer one - not that the class is unreachable.

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
    // The header types the layer nullable, so a source with no layer is a source the controller can
    // hold and report back; -isPictureInPicturePossible already answers NO for it, because it is
    // computed from this layer's readyForDisplay and player.
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

// The controller's own source, kept beside the class because a category cannot add an ivar, and
// putting one in the 9.0 object would make that object define 15.0 API - which release-split refuses
// as a mixed object. Associated storage keeps the 15.0 state inside the 15.0 object. The key is
// file-static, so nothing here is a new exported name.
static const void *CharonContentSourceKey = &CharonContentSourceKey;

// The controller's player layer is readonly in the SDK header and readwrite only in the 9.0 object's
// class extension, which this file cannot see. Redeclaring it readwrite here is the standard way to
// write to a property another object synthesized: the setter exists, it is -setPlayerLayer:, and the
// 9.0 object is the one that placed it.
@interface AVPictureInPictureController (CharonContentSource15)
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation AVPictureInPictureController (CharonContentSource15)

- (instancetype)initWithContentSource:(AVPictureInPictureControllerContentSource *)contentSource
{
    AVPlayerLayer *layer = contentSource.playerLayer;
    // A source with no player layer has nothing this port can float: its window reparents a
    // CALayer, and the release's sample-buffer half is not carried. Answering nil here is what
    // -initWithPlayerLayer: already does for a nil layer, so the two agree rather than one of them
    // inventing a controller with no source.
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
    // The header makes this a readwrite property. The window reparents exactly the layer it was
    // built with, so a source handed in later is recorded and its layer adopted as the one to float:
    // changing the layer under a controller that is already floating would strand the old one in
    // the window with nothing pointing at it.
    objc_setAssociatedObject(self, CharonContentSourceKey, contentSource, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (contentSource.playerLayer)
        self.playerLayer = contentSource.playerLayer;
}

@end
