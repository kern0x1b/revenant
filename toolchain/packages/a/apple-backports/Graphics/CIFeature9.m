#import <CoreImage/CoreImage.h>

@interface CITextFeature ()
- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
                         subFeatures:(NSArray *)subFeatureList;
@end

@implementation CITextFeature {
@private
    CGRect _bounds;
    CGPoint _topLeft;
    CGPoint _topRight;
    CGPoint _bottomLeft;
    CGPoint _bottomRight;
    NSArray *_subFeatures;
}

- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
                         subFeatures:(NSArray *)subFeatureList
{
    if ((self = [super init])) {
        _bounds = boundsRect;
        _topLeft = topLeftPoint;
        _topRight = topRightPoint;
        _bottomLeft = bottomLeftPoint;
        _bottomRight = bottomRightPoint;
        _subFeatures = [subFeatureList copy];
    }
    return self;
}

- (NSString *)type
{
    return CIFeatureTypeText;
}

- (CGRect)bounds
{
    return _bounds;
}

- (CGPoint)topLeft
{
    return _topLeft;
}

- (CGPoint)topRight
{
    return _topRight;
}

- (CGPoint)bottomLeft
{
    return _bottomLeft;
}

- (CGPoint)bottomRight
{
    return _bottomRight;
}

- (NSArray *)subFeatures
{
    return _subFeatures;
}

@end
