#import <CoreImage/CoreImage.h>

static void CharonEncodeValue(NSCoder *coder, NSString *key, const void *value, size_t size)
{
    [coder encodeObject:[NSData dataWithBytes:value length:size] forKey:key];
}

static BOOL CharonDecodeValue(NSCoder *coder, NSString *key, void *value, size_t size)
{
    NSData *data = [coder decodeObjectOfClass:[NSData class] forKey:key];
    if (data.length != size) {
        return NO;
    }
    memcpy(value, data.bytes, size);
    return YES;
}

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
