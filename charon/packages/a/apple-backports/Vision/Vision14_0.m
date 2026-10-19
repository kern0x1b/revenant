#import "CharonVision.h"
#import "CharonVisionContours.h"
#import <simd/simd.h>
#import <math.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"
#pragma clang diagnostic ignored "-Wprotocol"

/* Everything this file carries arrived in iOS 14.0, and it is the part of that release which is
 * arithmetic rather than a model: a point, a vector, a circle, the smallest circle around a set of
 * points, the base class a request that carries evidence over time is built on, and the two values
 * that say how often a video is analysed. None of it needs a Vision engine, and none of it needs
 * anything iOS 6 does not have - the arithmetic is doubles and the geometry is CoreGraphics, which
 * this library already links.
 *
 * What is NOT here is the part of 14.0 that runs a model: the contour, body pose, hand pose,
 * trajectory and optical flow requests, the observations only those requests produce, and the video
 * processor that would run a request over decoded video. Each of those rows says absent, and says
 * what is missing. */

static double charon_vision_squared_distance(double x1, double y1, double x2, double y2)
{
    double dx = x1 - x2, dy = y1 - y2;
    return dx * dx + dy * dy;
}

/* A point as the bounding circle works on it: two doubles, so the same code takes a VNPoint and the
 * simd_float2 buffer a contour is made of. */
typedef struct {
    double x;
    double y;
} CharonVisionXY;

/* The smallest circle that holds a set of points, found by the same three cases the algorithm is
 * written as: one point on its own, two as a diameter, three as the circle through them. `count` is
 * zero for a circle nothing has been found for yet, which is how the loops below tell "no circle"
 * from "a circle of radius zero". */
typedef struct {
    CharonVisionXY center;
    double radius;
    int count;
} CharonVisionCircle;

static CharonVisionCircle charon_vision_circle_of_one(CharonVisionXY point)
{
    CharonVisionCircle circle = {{point.x, point.y}, 0.0, 1};
    return circle;
}

static CharonVisionCircle charon_vision_circle_of_two(CharonVisionXY a, CharonVisionXY b)
{
    CharonVisionCircle circle;
    circle.center.x = (a.x + b.x) / 2.0;
    circle.center.y = (a.y + b.y) / 2.0;
    circle.radius = sqrt(charon_vision_squared_distance(a.x, a.y, b.x, b.y)) / 2.0;
    circle.count = 2;
    return circle;
}

/* Three points on one circle, unless they are on a line - and three points on a line have no circle
 * through them, so the one that holds all three is the one over the two farthest apart. */
static CharonVisionCircle charon_vision_circle_of_three(CharonVisionXY a, CharonVisionXY b, CharonVisionXY c)
{
    CharonVisionCircle circle;
    double d = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
    if (fabs(d) < 1e-18) {
        double ab = charon_vision_squared_distance(a.x, a.y, b.x, b.y);
        double ac = charon_vision_squared_distance(a.x, a.y, c.x, c.y);
        double bc = charon_vision_squared_distance(b.x, b.y, c.x, c.y);
        if (ab >= ac && ab >= bc)
            return charon_vision_circle_of_two(a, b);
        if (ac >= bc)
            return charon_vision_circle_of_two(a, c);
        return charon_vision_circle_of_two(b, c);
    }
    double a2 = a.x * a.x + a.y * a.y;
    double b2 = b.x * b.x + b.y * b.y;
    double c2 = c.x * c.x + c.y * c.y;
    circle.center.x = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d;
    circle.center.y = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d;
    circle.radius = sqrt(charon_vision_squared_distance(circle.center.x, circle.center.y, a.x, a.y));
    circle.count = 3;
    return circle;
}

/* Points are normalized, so the radius is of the order of one and this is the slack a point may sit
 * outside the circle by and still be treated as inside it. Without it the answer depends on the
 * order the points arrive in, which the caller does not choose. */
static BOOL charon_vision_circle_holds(CharonVisionCircle circle, CharonVisionXY point)
{
    if (circle.count == 0)
        return NO;
    return charon_vision_squared_distance(circle.center.x, circle.center.y, point.x, point.y)
        <= circle.radius * circle.radius + 1e-12;
}

/* The order the points are visited in is what decides how long the three loops below take, so they
 * are shuffled first. The generator is seeded with a constant on purpose: the same points then
 * answer the same circle on every run and on every device, which a clock-seeded shuffle would not. */
static void charon_vision_shuffle(CharonVisionXY *points, NSInteger count)
{
    uint32_t seed = 0x5f3759dfu;
    for (NSInteger index = count - 1; index > 0; index--) {
        CharonVisionXY swap;
        seed = seed * 1664525u + 1013904223u;
        NSInteger other = (NSInteger)(seed % (uint32_t)(index + 1));
        swap = points[index];
        points[index] = points[other];
        points[other] = swap;
    }
}

/* The smallest circle holding every point, or a circle of count zero when there is no point. The
 * argument is shuffled, so the caller hands over a copy it does not keep. */
static CharonVisionCircle charon_vision_bounding_circle(CharonVisionXY *points, NSInteger count)
{
    CharonVisionCircle circle = {{0.0, 0.0}, 0.0, 0};
    if (count <= 0)
        return circle;
    charon_vision_shuffle(points, count);
    for (NSInteger i = 0; i < count; i++) {
        if (charon_vision_circle_holds(circle, points[i]))
            continue;
        circle = charon_vision_circle_of_one(points[i]);
        for (NSInteger j = 0; j < i; j++) {
            if (charon_vision_circle_holds(circle, points[j]))
                continue;
            circle = charon_vision_circle_of_two(points[i], points[j]);
            for (NSInteger k = 0; k < j; k++) {
                if (charon_vision_circle_holds(circle, points[k]))
                    continue;
                circle = charon_vision_circle_of_three(points[i], points[j], points[k]);
            }
        }
    }
    return circle;
}

@implementation VNPoint {
    double _x;
    double _y;
}

+ (VNPoint *)zeroPoint
{
    static VNPoint *zero;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        zero = [[VNPoint alloc] initWithX:0.0 y:0.0];
    });
    return zero;
}

+ (VNPoint *)pointByApplyingVector:(VNVector *)vector toPoint:(VNPoint *)point
{
    if (vector == nil || point == nil) {
        return nil;
    }
    return [[self alloc] initWithX:point.x + vector.x y:point.y + vector.y];
}

+ (double)distanceBetweenPoint:(VNPoint *)point1 point:(VNPoint *)point2
{
    if (point1 == nil || point2 == nil) {
        return NAN;
    }
    return [point1 distanceToPoint:point2];
}

- (instancetype)initWithX:(double)x y:(double)y
{
    if ((self = [super init])) {
        _x = x;
        _y = y;
    }
    return self;
}

- (instancetype)initWithLocation:(CGPoint)location
{
    return [self initWithX:(double)location.x y:(double)location.y];
}

- (double)distanceToPoint:(VNPoint *)point
{
    if (point == nil) {
        return NAN;
    }
    return hypot(_x - point.x, _y - point.y);
}

- (CGPoint)location
{
    return CGPointMake((CGFloat)_x, (CGFloat)_y);
}

- (double)x
{
    return _x;
}

- (double)y
{
    return _y;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNPoint *copy = charon_vision_clone(self, zone);
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_x forKey:@"x"];
    [coder encodeDouble:_y forKey:@"y"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithX:[coder decodeDoubleForKey:@"x"] y:[coder decodeDoubleForKey:@"y"]];
}

@end

/* The point classes below are made by the port's own code, which is what their initialisers are for: the header marks
 * every initialiser of VNDetectedPoint and VNRecognizedPoint NS_UNAVAILABLE, and an application receives these points
 * from a request. The factories and setters are charon_ named, so they are not part of the surface the host shows. */
@interface VNDetectedPoint (CharonFactory)
+ (instancetype)charon_pointWithX:(double)x y:(double)y confidence:(VNConfidence)confidence;
@end

@interface VNRecognizedPoint (CharonFactory)
+ (instancetype)charon_pointWithX:(double)x y:(double)y confidence:(VNConfidence)confidence identifier:(VNRecognizedPointKey)identifier;
@end

@implementation VNDetectedPoint {
    VNConfidence _confidence;
}

+ (instancetype)charon_pointWithX:(double)x y:(double)y confidence:(VNConfidence)confidence
{
    VNDetectedPoint *point = [[self alloc] initWithX:x y:y];
    point->_confidence = confidence;
    return point;
}

- (VNConfidence)confidence
{
    return _confidence;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeFloat:_confidence forKey:@"confidence"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _confidence = [coder decodeFloatForKey:@"confidence"];
    }
    return self;
}

@end

@implementation VNRecognizedPoint {
    VNRecognizedPointKey _identifier;
}

+ (instancetype)charon_pointWithX:(double)x y:(double)y confidence:(VNConfidence)confidence identifier:(VNRecognizedPointKey)identifier
{
    VNRecognizedPoint *point = [super charon_pointWithX:x y:y confidence:confidence];
    point->_identifier = [identifier copy];
    return point;
}

- (VNRecognizedPointKey)identifier
{
    return _identifier;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_identifier forKey:@"identifier"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _identifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] copy];
    }
    return self;
}

@end

@implementation VNVector {
    double _x;
    double _y;
}

+ (VNVector *)zeroVector
{
    static VNVector *zero;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        zero = [[VNVector alloc] initWithXComponent:0.0 yComponent:0.0];
    });
    return zero;
}

+ (VNVector *)unitVectorForVector:(VNVector *)vector
{
    double length;
    if (vector == nil) {
        return nil;
    }
    length = vector.length;
    /* A vector of no length has no direction to preserve, so the unit vector of one is the zero
     * vector rather than a division by zero. */
    if (length == 0.0) {
        return [self zeroVector];
    }
    return [[self alloc] initWithXComponent:vector.x / length yComponent:vector.y / length];
}

+ (VNVector *)vectorByMultiplyingVector:(VNVector *)vector byScalar:(double)scalar
{
    if (vector == nil) {
        return nil;
    }
    return [[self alloc] initWithXComponent:vector.x * scalar yComponent:vector.y * scalar];
}

+ (VNVector *)vectorByAddingVector:(VNVector *)v1 toVector:(VNVector *)v2
{
    if (v1 == nil || v2 == nil) {
        return nil;
    }
    return [[self alloc] initWithXComponent:v1.x + v2.x yComponent:v1.y + v2.y];
}

+ (VNVector *)vectorBySubtractingVector:(VNVector *)v1 fromVector:(VNVector *)v2
{
    if (v1 == nil || v2 == nil) {
        return nil;
    }
    return [[self alloc] initWithXComponent:v2.x - v1.x yComponent:v2.y - v1.y];
}

+ (double)dotProductOfVector:(VNVector *)v1 vector:(VNVector *)v2
{
    if (v1 == nil || v2 == nil) {
        return NAN;
    }
    return v1.x * v2.x + v1.y * v2.y;
}

- (instancetype)initWithXComponent:(double)x yComponent:(double)y
{
    if ((self = [super init])) {
        _x = x;
        _y = y;
    }
    return self;
}

- (instancetype)initWithR:(double)r theta:(double)theta
{
    return [self initWithXComponent:r * cos(theta) yComponent:r * sin(theta)];
}

- (instancetype)initWithVectorHead:(VNPoint *)head tail:(VNPoint *)tail
{
    if (head == nil || tail == nil) {
        return nil;
    }
    return [self initWithXComponent:head.x - tail.x yComponent:head.y - tail.y];
}

- (double)x
{
    return _x;
}

- (double)y
{
    return _y;
}

- (double)r
{
    return self.length;
}

- (double)theta
{
    /* The header says the angle of the zero vector is not defined, and says so as NaN. */
    if (_x == 0.0 && _y == 0.0) {
        return NAN;
    }
    return atan2(_y, _x);
}

- (double)length
{
    return hypot(_x, _y);
}

- (double)squaredLength
{
    return _x * _x + _y * _y;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNVector *copy = charon_vision_clone(self, zone);
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_x forKey:@"x"];
    [coder encodeDouble:_y forKey:@"y"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithXComponent:[coder decodeDoubleForKey:@"x"] yComponent:[coder decodeDoubleForKey:@"y"]];
}

@end

@implementation VNCircle {
    VNPoint *_center;
    double _radius;
}

+ (VNCircle *)zeroCircle
{
    static VNCircle *zero;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        zero = [[VNCircle alloc] initWithCenter:[VNPoint zeroPoint] radius:0.0];
    });
    return zero;
}

- (instancetype)initWithCenter:(VNPoint *)center radius:(double)radius
{
    if ((self = [super init]) && center != nil) {
        _center = center;
        _radius = radius;
    }
    return self;
}

- (instancetype)initWithCenter:(VNPoint *)center diameter:(double)diameter
{
    return [self initWithCenter:center radius:diameter / 2.0];
}

- (BOOL)containsPoint:(VNPoint *)point
{
    if (point == nil || _center == nil) {
        return NO;
    }
    /* The boundary counts as inside, which is what the header says. */
    return [_center distanceToPoint:point] <= _radius;
}

- (BOOL)containsPoint:(VNPoint *)point inCircumferentialRingOfWidth:(double)ringWidth
{
    double distance;
    /* The header describes the ring as the band between the circles of radius-delta and
     * radius+delta, and names the argument the width of that band, so the half-width it compares
     * against is ringWidth/2. */
    if (point == nil || _center == nil) {
        return NO;
    }
    distance = [_center distanceToPoint:point];
    return distance >= _radius - ringWidth / 2.0 && distance <= _radius + ringWidth / 2.0;
}

- (VNPoint *)center
{
    return _center;
}

- (double)radius
{
    return _radius;
}

- (double)diameter
{
    return _radius * 2.0;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNCircle *copy = charon_vision_clone(self, zone);
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_center forKey:@"center"];
    [coder encodeDouble:_radius forKey:@"radius"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    VNPoint *center = [coder decodeObjectOfClass:[VNPoint class] forKey:@"center"];
    if (center == nil) {
        return nil;
    }
    return [self initWithCenter:center radius:[coder decodeDoubleForKey:@"radius"]];
}

@end

@implementation VNGeometryUtils

+ (VNCircle *)boundingCircleForPoints:(NSArray<VNPoint *> *)points error:(NSError **)error
{
    NSInteger count = (NSInteger)points.count;
    CharonVisionXY *buffer;
    CharonVisionCircle circle;
    VNCircle *answer;
    if (count == 0) {
        if (error) {
            *error = charon_vision_error(VNErrorInvalidArgument, @"there are no points to draw a circle around");
        }
        return nil;
    }
    buffer = malloc(sizeof(CharonVisionXY) * (size_t)count);
    if (buffer == NULL) {
        if (error) {
            *error = charon_vision_error(VNErrorOutOfMemory, @"the points would not fit in memory");
        }
        return nil;
    }
    for (NSInteger index = 0; index < count; index++) {
        VNPoint *point = points[(NSUInteger)index];
        if (point == nil) {
            free(buffer);
            if (error) {
                *error = charon_vision_error(VNErrorInvalidArgument, @"one of the points is not a VNPoint");
            }
            return nil;
        }
        buffer[index].x = point.x;
        buffer[index].y = point.y;
    }
    circle = charon_vision_bounding_circle(buffer, count);
    free(buffer);
    answer = [[VNCircle alloc] initWithCenter:[[VNPoint alloc] initWithX:circle.center.x y:circle.center.y]
                                       radius:circle.radius];
    return answer;
}

+ (VNCircle *)boundingCircleForSIMDPoints:(simd_float2 const *)points
                               pointCount:(NSInteger)pointCount
                                    error:(NSError **)error
{
    CharonVisionXY *buffer;
    CharonVisionCircle circle;
    VNCircle *answer;
    if (pointCount <= 0 || points == NULL) {
        if (error) {
            *error = charon_vision_error(VNErrorInvalidArgument, @"there are no points to draw a circle around");
        }
        return nil;
    }
    /* The caller's buffer is const, and the algorithm reorders the points it is given, so the
     * circle is found over a copy of them. */
    buffer = malloc(sizeof(CharonVisionXY) * (size_t)pointCount);
    if (buffer == NULL) {
        if (error) {
            *error = charon_vision_error(VNErrorOutOfMemory, @"the points would not fit in memory");
        }
        return nil;
    }
    for (NSInteger index = 0; index < pointCount; index++) {
        buffer[index].x = (double)points[index].x;
        buffer[index].y = (double)points[index].y;
    }
    circle = charon_vision_bounding_circle(buffer, pointCount);
    free(buffer);
    answer = [[VNCircle alloc] initWithCenter:[[VNPoint alloc] initWithX:circle.center.x y:circle.center.y]
                                       radius:circle.radius];
    return answer;
}

@end

@implementation VNStatefulRequest {
    CMTime _frameAnalysisSpacing;
}

/* A request that is handed the same buffer over and over and keeps what it learned. The spacing
 * says how often it is allowed to look: a buffer that arrives within one spacing of the last
 * analysis is skipped, and the request says so rather than guessing from a wall clock. */
- (instancetype)initWithFrameAnalysisSpacing:(CMTime)frameAnalysisSpacing
                           completionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _frameAnalysisSpacing = frameAnalysisSpacing;
    }
    return self;
}

/* The base class needs no frames before it can report: it carries the evidence a subclass collects
 * and has none of its own to wait for. A request that does need frames says so by overriding this,
 * which is the whole of the interface the header gives it. */
- (NSInteger)minimumLatencyFrameCount
{
    return 0;
}

- (CMTime)frameAnalysisSpacing
{
    return _frameAnalysisSpacing;
}

- (CMTime)requestFrameAnalysisSpacing
{
    return _frameAnalysisSpacing;
}

@end

@implementation VNVideoProcessorCadence

- (id)copyWithZone:(NSZone *)zone
{
    VNVideoProcessorCadence *copy = charon_vision_clone(self, zone);
    return copy;
}

@end

@implementation VNVideoProcessorFrameRateCadence {
    NSInteger _frameRate;
}

- (instancetype)initWithFrameRate:(NSInteger)frameRate
{
    if ((self = [super init])) {
        _frameRate = frameRate;
    }
    return self;
}

- (NSInteger)frameRate
{
    return _frameRate;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNVideoProcessorFrameRateCadence *copy = charon_vision_clone(self, zone);
    return copy;
}

@end

@implementation VNVideoProcessorTimeIntervalCadence {
    CFTimeInterval _timeInterval;
}

- (instancetype)initWithTimeInterval:(CFTimeInterval)timeInterval
{
    if ((self = [super init])) {
        _timeInterval = timeInterval;
    }
    return self;
}

- (CFTimeInterval)timeInterval
{
    return _timeInterval;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNVideoProcessorTimeIntervalCadence *copy = charon_vision_clone(self, zone);
    return copy;
}

@end

@implementation VNVideoProcessorRequestProcessingOptions {
    VNVideoProcessorCadence *_cadence;
}

/* The cadence of a request is its own to set, and the video processor reads it per request rather
 * than once for the whole pipeline, which is why it is on the options and not on the processor. */
- (VNVideoProcessorCadence *)cadence
{
    return _cadence;
}

- (void)setCadence:(VNVideoProcessorCadence *)cadence
{
    _cadence = [cadence copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    VNVideoProcessorRequestProcessingOptions *copy = charon_vision_clone(self, zone);
    return copy;
}

@end

/* The normalized point of an image point, the inverse of VNImagePointForNormalizedPoint. An image with a zero
 * width or height has no normalized coordinates, and the release answers the zero point for it whichever
 * axis is empty (measured on the host, facts/Vision/Coordinates.md). */
CGPoint VNNormalizedPointForImagePoint(CGPoint imagePoint, size_t imageWidth, size_t imageHeight)
{
    if (imageWidth == 0 || imageHeight == 0) {
        return CGPointZero;
    }
    return CGPointMake(imagePoint.x / (double)imageWidth, imagePoint.y / (double)imageHeight);
}

/* The contours of a picture. A path of the normalised points is held here rather than in the contour itself, so that the
 * contour declares no dealloc of its own: the path is released when the holder is. */
@interface CharonVisionPath : NSObject
- (instancetype)initWithPoints:(NSData *)points;
- (CGPathRef)path;
@end

@implementation CharonVisionPath {
    CGMutablePathRef _path;
}

- (instancetype)initWithPoints:(NSData *)points
{
    if ((self = [super init])) {
        const simd_float2 *values = (const simd_float2 *)points.bytes;
        NSUInteger count = points.length / sizeof(simd_float2);
        _path = CGPathCreateMutable();
        for (NSUInteger i = 0; i < count; i++) {
            CGPoint point = CGPointMake(values[i].x, values[i].y);
            if (i == 0)
                CGPathMoveToPoint(_path, NULL, point.x, point.y);
            else
                CGPathAddLineToPoint(_path, NULL, point.x, point.y);
        }
        if (count > 0)
            CGPathCloseSubpath(_path);
    }
    return self;
}

- (CGPathRef)path
{
    return _path;
}

- (void)dealloc
{
    CGPathRelease(_path);
}

@end

@implementation VNContour {
    NSIndexPath *_indexPath;
    NSArray<VNContour *> *_childContours;
    NSData *_points;
    CharonVisionPath *_path;
    float _aspectRatio;
}

/* Made by the contour request, which holds the points as simd_float2 values in walk order. The initialiser is named
 * for the port, since the header's own initialisers are NS_UNAVAILABLE. */
- (instancetype)initCharonWithIndexPath:(NSIndexPath *)indexPath points:(NSData *)points aspectRatio:(float)aspectRatio
{
    if ((self = [super init])) {
        _indexPath = indexPath;
        _childContours = @[];
        _points = [points copy];
        _path = [[CharonVisionPath alloc] initWithPoints:_points];
        _aspectRatio = aspectRatio;
    }
    return self;
}

- (void)charon_setChildContours:(NSArray<VNContour *> *)childContours
{
    _childContours = [childContours copy];
}

- (NSIndexPath *)indexPath
{
    return _indexPath;
}

- (NSInteger)pointCount
{
    return (NSInteger)(_points.length / sizeof(simd_float2));
}

- (const simd_float2 *)normalizedPoints
{
    return (const simd_float2 *)_points.bytes;
}

- (CGPathRef)normalizedPath
{
    return [_path path];
}

- (float)aspectRatio
{
    return _aspectRatio;
}

- (NSInteger)childContourCount
{
    return (NSInteger)_childContours.count;
}

- (NSArray<VNContour *> *)childContours
{
    return _childContours;
}

- (nullable VNContour *)childContourAtIndex:(NSUInteger)childContourIndex error:(NSError **)error
{
    if (childContourIndex >= _childContours.count) {
        if (error)
            *error = charon_vision_error(VNErrorInvalidArgument, @"the contour has no child at that index");
        return nil;
    }
    return _childContours[childContourIndex];
}

/* Douglas-Peucker on the closed polygon of the points, with the epsilon in normalised units. The release's own
 * simplification is not measured (facts/Vision/Contours14.md), so this is the classic algorithm and not a copy of it. */
- (nullable VNContour *)polygonApproximationWithEpsilon:(float)epsilon error:(NSError **)error
{
    NSInteger count = self.pointCount;
    const simd_float2 *values = self.normalizedPoints;
    if (count < 3) {
        return [[VNContour alloc] initCharonWithIndexPath:_indexPath points:_points aspectRatio:_aspectRatio];
    }
    BOOL *keep = calloc((size_t)count, sizeof(BOOL));
    NSInteger *stack = malloc(sizeof(NSInteger) * (size_t)count * 2);
    NSInteger top = 0;
    keep[0] = keep[count - 1] = YES;
    stack[top++] = 0;
    stack[top++] = count - 1;
    while (top > 0) {
        NSInteger last = stack[--top], first = stack[--top];
        double bestDistance = -1;
        NSInteger bestIndex = -1;
        for (NSInteger i = first + 1; i < last; i++) {
            double ax = values[first].x, ay = values[first].y, bx = values[last].x, by = values[last].y;
            double dx = bx - ax, dy = by - ay, length = hypot(dx, dy);
            double distance = length > 0 ? fabs(dy * (values[i].x - ax) - dx * (values[i].y - ay)) / length
                                         : hypot(values[i].x - ax, values[i].y - ay);
            if (distance > bestDistance) {
                bestDistance = distance;
                bestIndex = i;
            }
        }
        if (bestIndex >= 0 && bestDistance > epsilon) {
            keep[bestIndex] = YES;
            stack[top++] = first;
            stack[top++] = bestIndex;
            stack[top++] = bestIndex;
            stack[top++] = last;
        }
    }
    NSMutableData *kept = [NSMutableData data];
    for (NSInteger i = 0; i < count; i++) {
        if (keep[i])
            [kept appendBytes:&values[i] length:sizeof(simd_float2)];
    }
    free(keep);
    free(stack);
    return [[VNContour alloc] initCharonWithIndexPath:_indexPath points:kept aspectRatio:_aspectRatio];
}

@end

@implementation VNContoursObservation {
    NSArray<VNContour *> *_topLevelContours;
    NSArray<VNContour *> *_allContours;
    CharonVisionPath *_path;
}

- (instancetype)initCharonWithTopLevelContours:(NSArray<VNContour *> *)topLevelContours allContours:(NSArray<VNContour *> *)allContours
                                      normalizedPoints:(NSData *)points
{
    if ((self = [super init])) {
        _topLevelContours = [topLevelContours copy];
        _allContours = [allContours copy];
        _path = [[CharonVisionPath alloc] initWithPoints:points];
    }
    return self;
}

- (NSInteger)contourCount
{
    return (NSInteger)_allContours.count;
}

- (NSInteger)topLevelContourCount
{
    return (NSInteger)_topLevelContours.count;
}

- (NSArray<VNContour *> *)topLevelContours
{
    return _topLevelContours;
}

- (CGPathRef)normalizedPath
{
    return [_path path];
}

- (nullable VNContour *)contourAtIndex:(NSInteger)contourIndex error:(NSError **)error
{
    if (contourIndex < 0 || (NSUInteger)contourIndex >= _allContours.count) {
        if (error)
            *error = charon_vision_error(VNErrorInvalidArgument, @"the observation has no contour at that index");
        return nil;
    }
    return _allContours[(NSUInteger)contourIndex];
}

- (nullable VNContour *)contourAtIndexPath:(NSIndexPath *)indexPath error:(NSError **)error
{
    VNContour *contour = nil;
    if (indexPath.length > 0) {
        NSArray<VNContour *> *level = _topLevelContours;
        for (NSUInteger depth = 0; depth < indexPath.length; depth++) {
            NSUInteger index = [indexPath indexAtPosition:depth];
            if (index >= level.count) {
                level = nil;
                break;
            }
            contour = level[index];
            level = contour.childContours;
        }
    }
    if (contour == nil && error)
        *error = charon_vision_error(VNErrorInvalidArgument, @"the observation has no contour at that index path");
    return contour;
}

@end

/* The grey value of each pixel of the picture a request is given, from 0 to 1: a Core Graphics image is drawn into a
 * grey bitmap of the size asked for, and a pixel buffer's blue, green and red are averaged with the weights of the
 * luma that Vision reads (the weights are not measured, and do not matter for a binary picture). */
static uint8_t *charon_contours_grey(id image, size_t wide, size_t high)
{
    uint8_t *grey = malloc(wide * high);
    if (grey == NULL)
        return NULL;
    if (CFGetTypeID((__bridge CFTypeRef)image) == CGImageGetTypeID()) {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
        CGContextRef context = CGBitmapContextCreate(grey, wide, high, 8, wide, space, kCGImageAlphaNone);
        CGColorSpaceRelease(space);
        if (context == NULL) {
            free(grey);
            return NULL;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, wide, high), (__bridge CGImageRef)image);
        CGContextRelease(context);
        return grey;
    }
    CVPixelBufferRef buffer = (__bridge CVPixelBufferRef)image;
    if (CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) {
        free(grey);
        return NULL;
    }
    const uint8_t *bytes = CVPixelBufferGetBaseAddress(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    size_t sourceWide = CVPixelBufferGetWidth(buffer), sourceHigh = CVPixelBufferGetHeight(buffer);
    // nearest sampling: a buffer scaled down to the maximum dimension takes the pixel at the same place in the source
    for (size_t y = 0; y < high; y++) {
        for (size_t x = 0; x < wide; x++) {
            const uint8_t *pixel = bytes + (y * sourceHigh / high) * stride + (x * sourceWide / wide) * 4;
            grey[y * wide + x] = (uint8_t)((pixel[0] * 114 + pixel[1] * 587 + pixel[2] * 299) / 1000);
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    return grey;
}

@implementation VNDetectContoursRequest {
    float _contrastAdjustment;
    BOOL _detectsDarkOnLight;
    NSUInteger _maximumImageDimension;
    NSNumber *_contrastPivotValue;
}

/* The results are the request's own declaration in the header; the value is the one VNRequest holds, which the accessor reads. */
@dynamic results;

+ (NSIndexSet *)supportedRevisions
{
    return [NSIndexSet indexSetWithIndex:1];
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler])) {
        _contrastAdjustment = 2;
        _detectsDarkOnLight = YES;
        _maximumImageDimension = 512;
    }
    return self;
}

- (float)contrastAdjustment
{
    return _contrastAdjustment;
}

- (void)setContrastAdjustment:(float)contrastAdjustment
{
    _contrastAdjustment = contrastAdjustment;
}

- (BOOL)detectsDarkOnLight
{
    return _detectsDarkOnLight;
}

- (void)setDetectsDarkOnLight:(BOOL)detectsDarkOnLight
{
    _detectsDarkOnLight = detectsDarkOnLight;
}

- (BOOL)detectDarkOnLight
{
    return _detectsDarkOnLight;
}

- (void)setDetectDarkOnLight:(BOOL)detectDarkOnLight
{
    _detectsDarkOnLight = detectDarkOnLight;
}

- (NSUInteger)maximumImageDimension
{
    return _maximumImageDimension;
}

- (void)setMaximumImageDimension:(NSUInteger)maximumImageDimension
{
    _maximumImageDimension = maximumImageDimension;
}

/* The contrast pivot is a 15.0 property: its accessors are in Vision15_0.m, which reads and writes these. */
- (NSNumber *)charon_contrastPivotValue
{
    return _contrastPivotValue;
}

- (void)charon_setContrastPivotValue:(NSNumber *)value
{
    _contrastPivotValue = [value copy];
}

- (NSArray<VNContoursObservation *> *)charon_observationsOnImage:(id)image error:(NSError **)error
{
    size_t wide = 0, high = 0;
    CFTypeID type = CFGetTypeID((__bridge CFTypeRef)image);
    if (type == CGImageGetTypeID()) {
        wide = CGImageGetWidth((__bridge CGImageRef)image);
        high = CGImageGetHeight((__bridge CGImageRef)image);
    } else {
        wide = CVPixelBufferGetWidth((__bridge CVPixelBufferRef)image);
        high = CVPixelBufferGetHeight((__bridge CVPixelBufferRef)image);
    }
    if (wide == 0 || high == 0) {
        if (error)
            *error = charon_vision_error(VNErrorInvalidImage, @"the image has no pixels");
        return nil;
    }
    /* A picture larger than the maximum dimension is scaled down to it. The release's scaling is not measured, so this one
     * is a plain bitmap draw, and a picture within the maximum (every test picture) is not scaled at all. */
    size_t largest = wide > high ? wide : high;
    if (largest > _maximumImageDimension && _maximumImageDimension > 0) {
        wide = wide * _maximumImageDimension / largest;
        high = high * _maximumImageDimension / largest;
        if (wide == 0) wide = 1;
        if (high == 0) high = 1;
    }
    uint8_t *grey = charon_contours_grey(image, wide, high);
    if (grey == NULL) {
        if (error)
            *error = charon_vision_error(VNErrorInvalidImage, @"the image could not be read");
        return nil;
    }
    double pivot = _contrastPivotValue ? _contrastPivotValue.doubleValue : 0.5;
    uint8_t *foreground = malloc(wide * high);
    for (size_t i = 0; i < wide * high; i++) {
        double value = (grey[i] / 255.0 - 0.5) * _contrastAdjustment + 0.5;
        foreground[i] = _detectsDarkOnLight ? value < pivot : value > pivot;
    }
    free(grey);
    int count = 0;
    charon_contour *curves = charon_contours_trace(foreground, (int)wide, (int)high, &count);
    free(foreground);

    float aspect = (float)wide / (float)high;
    NSMutableArray<NSMutableArray<NSNumber *> *> *children = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *roots = [NSMutableArray array];
    for (int i = 0; i < count; i++)
        [children addObject:[NSMutableArray array]];
    for (int i = 0; i < count; i++) {
        if (curves[i].parent < 0)
            [roots addObject:@(i)];
        else
            [children[curves[i].parent] addObject:@(i)];
    }
    /* siblings in the raster order of the pixel each one encloses */
    NSComparator byPixel = ^NSComparisonResult(NSNumber *a, NSNumber *b) {
        const charon_contour *ca = &curves[a.intValue], *cb = &curves[b.intValue];
        if (ca->sampleY != cb->sampleY)
            return ca->sampleY < cb->sampleY ? NSOrderedAscending : NSOrderedDescending;
        return ca->sampleX < cb->sampleX ? NSOrderedAscending : (ca->sampleX > cb->sampleX ? NSOrderedDescending : NSOrderedSame);
    };
    [roots sortUsingComparator:byPixel];
    for (NSMutableArray *list in children)
        [list sortUsingComparator:byPixel];

    NSMutableArray<VNContour *> *all = [NSMutableArray array];
    NSMutableArray<VNContour *> *top = [NSMutableArray array];
    NSMutableData *allPoints = [NSMutableData data];
    /* the contours are built depth-first, a parent before its children, and each one's index path is its parent's with its own
     * position in the sibling list appended */
    __block void (^build)(NSNumber *, NSIndexPath *, NSMutableArray<VNContour *> *);
    build = ^(NSNumber *index, NSIndexPath *path, NSMutableArray<VNContour *> *into) {
        const charon_contour *c = &curves[index.intValue];
        NSMutableData *points = [NSMutableData dataWithLength:sizeof(simd_float2) * (NSUInteger)c->count];
        simd_float2 *values = (simd_float2 *)points.mutableBytes;
        for (int i = 0; i < c->count; i++) {
            double mx, my;
            charon_contour_midpoint(c, i, &mx, &my);
            values[i].x = (float)(mx / (double)wide);
            values[i].y = (float)((high - my) / (double)high);
        }
        VNContour *contour = [[VNContour alloc] initCharonWithIndexPath:path points:points aspectRatio:aspect];
        [into addObject:contour];
        [all addObject:contour];
        [allPoints appendData:points];
        NSMutableArray<VNContour *> *kids = [NSMutableArray array];
        NSUInteger position = 0;
        for (NSNumber *child in children[index.intValue]) {
            build(child, [path indexPathByAddingIndex:position++], kids);
        }
        [contour charon_setChildContours:kids];
    };
    NSUInteger root = 0;
    for (NSNumber *index in roots)
        build(index, [NSIndexPath indexPathWithIndex:root++], top);
    free(curves);
    VNContoursObservation *observation = [[VNContoursObservation alloc] initCharonWithTopLevelContours:top allContours:all normalizedPoints:allPoints];
    return @[observation];
}

@end
