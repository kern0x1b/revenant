// ARImageAnchor.m - a tracked image, at 11.3 where it arrived with ARReferenceImage.
//
// An anchor whose thing in the world is a printed picture: it carries the reference image it was found
// from, and the scale the session measured against it. Both come from the camera, so this is carried
// whole on this device and neither initialiser is available - an image anchor exists because the
// session found the picture, not because a caller asked for one.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ARImageAnchor ()
@property (nonatomic, assign) CGFloat scale;
@end

@implementation ARImageAnchor

@synthesize referenceImage = _referenceImage;
@synthesize estimatedScaleFactor = _estimatedScaleFactor;
@synthesize scale = _scale;

- (BOOL)isTracked
{
    // The session owns the lifetime here too: an anchor the session has released is one whose weak
    // reference has gone, and that is the same answer as one the session never found.
    return _referenceImage != nil;
}

@end

NS_ASSUME_NONNULL_END
