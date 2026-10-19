// SpriteKit8.m - the iOS 8 members of SpriteKit that the port carries: SKUniform, the points and spline forms of
// SKShapeNode, and its stroke and fill textures, carried for the releases that have no SpriteKit at all.
//
// A uniform is a value: a name, a type and one payload that the type says is read back. The behaviour is measured
// against the host's own SpriteKit in facts/SpriteKit/SKUniform.md: the factories set the type they name, a setter
// of the payload moves a None uniform to the payload's type and leaves any other type alone, and a copy keeps the
// type and the payload. Nothing here draws. A shader needs SpriteKit's renderer, which the port does not carry, so
// the uniform is held for the application and read back, and no SKShader is carried by this file.
//
// SKTexture is SpriteKit's own class and the release has none, so this file never names it as a class: a texture is
// the object the caller hands in, and an archive reads its class by name at run time, so no SpriteKit symbol is
// imported (a strong reference to one would stop dyld at launch on a release without SpriteKit).
#import "CharonSpriteKit.h"
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

// A uniform made without a payload takes the type of the first payload it is given, nil included for a texture:
// the host makes a None uniform a Texture on setTextureValue:nil as well (differential.m). One that already has a
// type keeps it, for both the float and the texture.
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

// The keys are the port's own, and the archive is read back by the port alone: the host's archive format is not
// claimed by this file (facts/SpriteKit/SKUniform.md).
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

// SKNode's subscript of iOS 8: every node a path picks out, in the order childNodeWithName: would list them.
@implementation SKNode (CharonSpriteKit8)

- (NSArray *)objectForKeyedSubscript:(NSString *)path
{
    return [self charon_nodesMatchingPath:path];
}

@end

// The point of the spline's sequence at an index. The first point is repeated in front of the points, so the spline
// starts with a segment that does not move (measured on the host: the element after the move ends on the first point).
static CGPoint CharonSKSplinePoint(const CGPoint *points, size_t index)
{
    return points[index == 0 ? 0 : index - 1];
}

// The tangent of the spline at an index of the sequence: half the chord between its neighbours, clamped at the ends
// (measured: the tangent at the first index is zero, and at the last it is half the chord of the last two points).
static CGPoint CharonSKSplineTangent(const CGPoint *points, size_t numPoints, size_t index)
{
    size_t next = index < numPoints ? index + 1 : numPoints;
    size_t previous = index > 0 ? index - 1 : 0;
    CGPoint after = CharonSKSplinePoint(points, next);
    CGPoint before = CharonSKSplinePoint(points, previous);
    return CGPointMake((after.x - before.x) / 2, (after.y - before.y) / 2);
}

// The keys of the textures of the stroke and fill, which the category holds by associated objects.
static const void *CharonSKFillTextureKey = &CharonSKFillTextureKey;
static const void *CharonSKStrokeTextureKey = &CharonSKStrokeTextureKey;

// The points form of SKShapeNode is of iOS 8 (measured on the host: no points give an empty path, one point a path of a
// single point closed, and more points a polyline closed back to the first point). The spline form is a Catmull-Rom
// curve through the points, with each segment's control points a third of its tangents away from its ends (measured:
// the element count is the number of points plus one, and the curve passes through every point; the bounding box of
// four points on a square of side 10 is (-1.67, -1.67, 13.33, 13.33)).
@implementation SKShapeNode (CharonSpriteKitShape8)

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
        CGPoint start = CharonSKSplinePoint(points, 0);
        CGPathMoveToPoint(path, NULL, start.x, start.y);
        for (size_t index = 0; index < numPoints; index++) {
            CGPoint from = CharonSKSplinePoint(points, index);
            CGPoint to = CharonSKSplinePoint(points, index + 1);
            CGPoint fromTangent = CharonSKSplineTangent(points, numPoints, index);
            CGPoint toTangent = CharonSKSplineTangent(points, numPoints, index + 1);
            CGPathAddCurveToPoint(path, NULL, from.x + fromTangent.x / 3, from.y + fromTangent.y / 3,
                                  to.x - toTangent.x / 3, to.y - toTangent.y / 3, to.x, to.y);
        }
    }
    SKShapeNode *node = [self shapeNodeWithPath:path];
    CGPathRelease(path);
    return node;
}

// The textures are stored as the host stores them (measured: a texture set reads back as the same object, and nil clears
// it; setting one does not change the colours or the other texture). Nothing is drawn yet: the renderer is owed.
- (SKTexture *)fillTexture
{
    return objc_getAssociatedObject(self, CharonSKFillTextureKey);
}

- (void)setFillTexture:(SKTexture *)fillTexture
{
    objc_setAssociatedObject(self, CharonSKFillTextureKey, fillTexture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SKTexture *)strokeTexture
{
    return objc_getAssociatedObject(self, CharonSKStrokeTextureKey);
}

- (void)setStrokeTexture:(SKTexture *)strokeTexture
{
    objc_setAssociatedObject(self, CharonSKStrokeTextureKey, strokeTexture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
