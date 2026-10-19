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
    return _referenceImage != nil;
}

@end

NS_ASSUME_NONNULL_END
