// CIRectangleFeature and CIQRCodeFeature, as CIFeature.h declares them, on top of the release's own CIFeature.
//
// WHAT A FEATURE IS: the header calls CIFeature "generic feature found by a CIDetector", and the release
// carries that base class with `type` and `bounds`. The two subclasses here add the members the header gives
// them and answer `type` with the header's constant. Nothing in this file finds anything: the detectors that
// would make these objects are not in this port (facts/CoreImage/Features.md, the open item), so a feature
// is made only by the private initializers below, which the tests call through a category of their own.
//
// WHICH RELEASE: 8.0. CIFeature.h gives both classes NS_CLASS_AVAILABLE(10_10, 8_0). CIQRCodeFeature's
// symbolDescriptor is NS_AVAILABLE(10_13, 11_0), so it is not here: it sits in CIQRCodeFeature11.m, the
// category of the 11.0 split, as the house does for the other members a later release added.
//
// The corners are the header's own: topLeft, topRight, bottomLeft and bottomRight, each "relative to the
// original image", and the host answers them in the order the header names.

#import <CoreImage/CoreImage.h>

// The NSCoder geometry methods live in UIKit, which this image does not link, so a rectangle or a point is
// archived as its bytes, the way a value is held in the archive it was written to.
static void CharonEncodeValue(NSCoder *coder, NSString *key, const void *value, size_t size)
{
    [coder encodeObject:[NSData dataWithBytes:value length:size] forKey:key];
}

// NO when the archive does not hold the value of this size: the feature is then not decoded at all, rather than
// decoded with a zero geometry that looks like a real answer.
static BOOL CharonDecodeValue(NSCoder *coder, NSString *key, void *value, size_t size)
{
    NSData *data = [coder decodeObjectOfClass:[NSData class] forKey:key];
    if (data.length != size) {
        return NO;
    }
    memcpy(value, data.bytes, size);
    return YES;
}

// The initializer of a feature the port makes. Declared here, and not in a header, because no caller outside
// this family may make one: a feature is what a detector hands back.
@interface CIRectangleFeature ()
- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint;
@end

@implementation CIRectangleFeature {
@private
    CGRect _bounds;
    CGPoint _topLeft;
    CGPoint _topRight;
    CGPoint _bottomLeft;
    CGPoint _bottomRight;
}

- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
{
    if ((self = [super init])) {
        _bounds = boundsRect;
        _topLeft = topLeftPoint;
        _topRight = topRightPoint;
        _bottomLeft = bottomLeftPoint;
        _bottomRight = bottomRightPoint;
    }
    return self;
}

- (NSString *)type
{
    return CIFeatureTypeRectangle;
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

@end

@interface CIQRCodeFeature () <NSSecureCoding, NSCopying>
- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
                        messageString:(NSString *)message;
@end

@implementation CIQRCodeFeature {
@private
    CGRect _bounds;
    CGPoint _topLeft;
    CGPoint _topRight;
    CGPoint _bottomLeft;
    CGPoint _bottomRight;
    NSString *_messageString;
}

// symbolDescriptor is the 11.0 member, implemented by the category in CIQRCodeFeature11.m; no getter is made here.
@dynamic symbolDescriptor;

- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
                        messageString:(NSString *)message
{
    if ((self = [super init])) {
        _bounds = boundsRect;
        _topLeft = topLeftPoint;
        _topRight = topRightPoint;
        _bottomLeft = bottomLeftPoint;
        _bottomRight = bottomRightPoint;
        _messageString = [message copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (NSString *)type
{
    return CIFeatureTypeQRCode;
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

- (NSString *)messageString
{
    return _messageString;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithCharonBounds:_bounds
                                                           topLeft:_topLeft
                                                          topRight:_topRight
                                                        bottomLeft:_bottomLeft
                                                       bottomRight:_bottomRight
                                                     messageString:_messageString];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_messageString forKey:@"messageString"];
    CharonEncodeValue(coder, @"bounds", &_bounds, sizeof(_bounds));
    CharonEncodeValue(coder, @"topLeft", &_topLeft, sizeof(_topLeft));
    CharonEncodeValue(coder, @"topRight", &_topRight, sizeof(_topRight));
    CharonEncodeValue(coder, @"bottomLeft", &_bottomLeft, sizeof(_bottomLeft));
    CharonEncodeValue(coder, @"bottomRight", &_bottomRight, sizeof(_bottomRight));
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    CGRect boundsValue = CGRectZero;
    CGPoint topLeftValue = CGPointZero, topRightValue = CGPointZero, bottomLeftValue = CGPointZero, bottomRightValue = CGPointZero;
    if (!CharonDecodeValue(coder, @"bounds", &boundsValue, sizeof(boundsValue))
        || !CharonDecodeValue(coder, @"topLeft", &topLeftValue, sizeof(topLeftValue))
        || !CharonDecodeValue(coder, @"topRight", &topRightValue, sizeof(topRightValue))
        || !CharonDecodeValue(coder, @"bottomLeft", &bottomLeftValue, sizeof(bottomLeftValue))
        || !CharonDecodeValue(coder, @"bottomRight", &bottomRightValue, sizeof(bottomRightValue))) {
        return nil;
    }
    NSString *message = [coder decodeObjectOfClass:[NSString class] forKey:@"messageString"];
    return [self initWithCharonBounds:boundsValue
                              topLeft:topLeftValue
                             topRight:topRightValue
                           bottomLeft:bottomLeftValue
                          bottomRight:bottomRightValue
                        messageString:message];
}

@end
