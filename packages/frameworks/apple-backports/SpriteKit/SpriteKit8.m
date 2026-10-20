#import "RevenantSpriteKit.h"
#include <objc/runtime.h>

@implementation SKUniform {
    NSString *_name;
    SKUniformType _uniformType;
    float _floatValue;
    SKTexture *_textureValue;
}

+ (instancetype)uniformWithName:(NSString *)name
{
    return [[self alloc] initWithName:name];
}

+ (instancetype)uniformWithName:(NSString *)name texture:(SKTexture *)texture
{
    return [[self alloc] initWithName:name texture:texture];
}

+ (instancetype)uniformWithName:(NSString *)name float:(float)value
{
    return [[self alloc] initWithName:name float:value];
}

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        _name = [name copy];
        _uniformType = SKUniformTypeNone;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name texture:(SKTexture *)texture
{
    self = [self initWithName:name];
    if (self) {
        _textureValue = texture;
        _uniformType = SKUniformTypeTexture;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name float:(float)value
{
    self = [self initWithName:name];
    if (self) {
        _floatValue = value;
        _uniformType = SKUniformTypeFloat;
    }
    return self;
}

- (NSString *)name
{
    return _name;
}

- (SKUniformType)uniformType
{
    return _uniformType;
}

- (float)floatValue
{
    return _floatValue;
}

- (void)setFloatValue:(float)floatValue
{
    _floatValue = floatValue;
    if (_uniformType == SKUniformTypeNone) {
        _uniformType = SKUniformTypeFloat;
    }
}

- (SKTexture *)textureValue
{
    return _textureValue;
}

- (void)setTextureValue:(SKTexture *)textureValue
{
    _textureValue = textureValue;
    if (_uniformType == SKUniformTypeNone) {
        _uniformType = SKUniformTypeTexture;
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    SKUniform *copy = [[[self class] alloc] initWithName:_name];
    copy->_uniformType = _uniformType;
    copy->_floatValue = _floatValue;
    copy->_textureValue = _textureValue;
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _uniformType = (SKUniformType)[coder decodeIntegerForKey:@"uniformType"];
        _floatValue = [coder decodeFloatForKey:@"floatValue"];
        Class texture = NSClassFromString(@"SKTexture");
        if (texture != Nil && [coder containsValueForKey:@"textureValue"]) {
            _textureValue = [coder decodeObjectOfClass:texture forKey:@"textureValue"];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeInteger:_uniformType forKey:@"uniformType"];
    [coder encodeFloat:_floatValue forKey:@"floatValue"];
    if (_textureValue != nil) {
        [coder encodeObject:_textureValue forKey:@"textureValue"];
    }
}

@end

@implementation SKNode (RevenantSpriteKit8)

- (NSArray *)objectForKeyedSubscript:(NSString *)path
{
    return [self revenant_nodesMatchingPath:path];
}

@end

static CGPoint RevenantSKSplinePoint(const CGPoint *points, size_t index)
{
    return points[index == 0 ? 0 : index - 1];
}

static CGPoint RevenantSKSplineTangent(const CGPoint *points, size_t numPoints, size_t index)
{
    size_t next = index < numPoints ? index + 1 : numPoints;
    size_t previous = index > 0 ? index - 1 : 0;
    CGPoint after = RevenantSKSplinePoint(points, next);
    CGPoint before = RevenantSKSplinePoint(points, previous);
    return CGPointMake((after.x - before.x) / 2, (after.y - before.y) / 2);
}

static const void *RevenantSKFillTextureKey = &RevenantSKFillTextureKey;
static const void *RevenantSKStrokeTextureKey = &RevenantSKStrokeTextureKey;

@implementation SKShapeNode (RevenantSpriteKitShape8)

+ (instancetype)shapeNodeWithPoints:(CGPoint *)points count:(size_t)numPoints
{
    CGMutablePathRef path = CGPathCreateMutable();
    if (numPoints > 0) {
        CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
        for (size_t index = 1; index < numPoints; index++) {
            CGPathAddLineToPoint(path, NULL, points[index].x, points[index].y);
        }
        CGPathCloseSubpath(path);
    }
    SKShapeNode *node = [self shapeNodeWithPath:path];
    CGPathRelease(path);
    return node;
}

+ (instancetype)shapeNodeWithSplinePoints:(CGPoint *)points count:(size_t)numPoints
{
    CGMutablePathRef path = CGPathCreateMutable();
    if (numPoints > 0) {
        CGPoint start = RevenantSKSplinePoint(points, 0);
        CGPathMoveToPoint(path, NULL, start.x, start.y);
        for (size_t index = 0; index < numPoints; index++) {
            CGPoint from = RevenantSKSplinePoint(points, index);
            CGPoint to = RevenantSKSplinePoint(points, index + 1);
            CGPoint fromTangent = RevenantSKSplineTangent(points, numPoints, index);
            CGPoint toTangent = RevenantSKSplineTangent(points, numPoints, index + 1);
            CGPathAddCurveToPoint(path, NULL, from.x + fromTangent.x / 3, from.y + fromTangent.y / 3,
                                  to.x - toTangent.x / 3, to.y - toTangent.y / 3, to.x, to.y);
        }
    }
    SKShapeNode *node = [self shapeNodeWithPath:path];
    CGPathRelease(path);
    return node;
}

- (SKTexture *)fillTexture
{
    return objc_getAssociatedObject(self, RevenantSKFillTextureKey);
}

- (void)setFillTexture:(SKTexture *)fillTexture
{
    objc_setAssociatedObject(self, RevenantSKFillTextureKey, fillTexture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SKTexture *)strokeTexture
{
    return objc_getAssociatedObject(self, RevenantSKStrokeTextureKey);
}

- (void)setStrokeTexture:(SKTexture *)strokeTexture
{
    objc_setAssociatedObject(self, RevenantSKStrokeTextureKey, strokeTexture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
